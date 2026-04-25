using MapsterMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using System;
using System.Linq;
using System.Net;
using Microsoft.EntityFrameworkCore.Storage;
using EasyPark.Model;
using EasyPark.Model.Models;
using EasyPark.Model.Requests;
using EasyPark.Model.SearchObjects;
using EasyPark.Services.Database;
using EasyPark.Services.Helpers;
using EasyPark.Services.Interfaces;
using EasyPark.Services.Pdf;
using TransactionModel = EasyPark.Model.Models.Transaction;
using TransactionDb = EasyPark.Services.Database.Transaction;

namespace EasyPark.Services.Services
{
    public class TransactionService : BaseCRUDService<TransactionModel, TransactionSearchObject, TransactionDb, TransactionInsertRequest, TransactionUpdateRequest>, ITransactionService
    {
        private readonly IHttpContextAccessor _httpContextAccessor;

        public TransactionService(EasyParkDbContext context, IMapper mapper, IHttpContextAccessor httpContextAccessor) : base(context, mapper)
        {
            _httpContextAccessor = httpContextAccessor;
        }

        public override IQueryable<TransactionDb> AddFilter(TransactionSearchObject search, IQueryable<TransactionDb> query)
        {
            var filteredQuery = base.AddFilter(search, query);

            filteredQuery = filteredQuery
                .Include(t => t.User)
                .Include(t => t.Reservation);

            if (search.ReservationId.HasValue)
            {
                filteredQuery = filteredQuery.Where(t => t.ReservationId == search.ReservationId.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.Status))
            {
                filteredQuery = filteredQuery.Where(t => t.Status == search.Status);
            }

            if (!string.IsNullOrWhiteSpace(search.PaymentMethod))
            {
                filteredQuery = filteredQuery.Where(t => t.PaymentMethod == search.PaymentMethod);
            }

            if (search.CreatedFrom.HasValue)
            {
                filteredQuery = filteredQuery.Where(t => t.CreatedAt >= search.CreatedFrom.Value);
            }

            if (search.CreatedTo.HasValue)
            {
                filteredQuery = filteredQuery.Where(t => t.CreatedAt <= search.CreatedTo.Value);
            }

            if (search.MinAmount.HasValue)
            {
                filteredQuery = filteredQuery.Where(t => t.Amount >= search.MinAmount.Value);
            }

            if (search.MaxAmount.HasValue)
            {
                filteredQuery = filteredQuery.Where(t => t.Amount <= search.MaxAmount.Value);
            }

            if (CurrentUserHelper.IsAdmin(_httpContextAccessor) && search.UserId.HasValue)
            {
                filteredQuery = filteredQuery.Where(t => t.UserId == search.UserId.Value);
            }
            else if (!CurrentUserHelper.IsAdmin(_httpContextAccessor))
            {
                var uid = CurrentUserHelper.GetRequiredUserId(_httpContextAccessor);
                filteredQuery = filteredQuery.Where(t => t.UserId == uid);
            }

            filteredQuery = filteredQuery.OrderByDescending(t => t.CreatedAt);

            return filteredQuery;
        }

        public override void BeforeInsert(TransactionInsertRequest request, TransactionDb entity)
        {
            if (request.Amount <= 0)
            {
                throw new UserException("Amount must be greater than 0", HttpStatusCode.BadRequest);
            }

            var validPaymentMethods = new[] { "Stripe", "Cash" };
            if (!validPaymentMethods.Contains(request.PaymentMethod))
            {
                throw new UserException($"Invalid payment method. Valid methods are: {string.Join(", ", validPaymentMethods)}", HttpStatusCode.BadRequest);
            }

            if (request.ReservationId.HasValue)
            {
                var reservation = Context.Reservations.Find(request.ReservationId.Value);
                if (reservation == null)
                {
                    throw new UserException("Reservation not found", HttpStatusCode.NotFound);
                }
            }

            entity.UserId = CurrentUserHelper.GetRequiredUserId(_httpContextAccessor);
            entity.Status = "Pending";
            entity.Currency = request.Currency ?? "BAM";
            entity.CreatedAt = DateTime.UtcNow;
        }

        public override void BeforeUpdate(TransactionUpdateRequest request, TransactionDb entity)
        {
            if (entity == null)
            {
                throw new UserException("Transaction not found", HttpStatusCode.NotFound);
            }

            if (!string.IsNullOrWhiteSpace(request.Status))
            {
                var validStatuses = new[] { "Pending", "Completed", "Failed", "Refunded" };
                if (!validStatuses.Contains(request.Status))
                {
                    throw new UserException($"Invalid status. Valid statuses are: {string.Join(", ", validStatuses)}", HttpStatusCode.BadRequest);
                }

                if (request.Status == "Completed" && !entity.PaymentDate.HasValue)
                {
                    entity.PaymentDate = DateTime.UtcNow;
                }
            }
        }

        public override TransactionModel GetById(int id)
        {
            var entity = Context.Set<TransactionDb>()
                .Include(t => t.User)
                .Include(t => t.Reservation)
                .FirstOrDefault(t => t.Id == id);

            if (entity == null)
            {
                throw new UserException("Transaction not found", HttpStatusCode.NotFound);
            }

            if (!CurrentUserHelper.IsAdmin(_httpContextAccessor) &&
                entity.UserId != CurrentUserHelper.GetRequiredUserId(_httpContextAccessor))
            {
                throw new UserException("Forbidden", HttpStatusCode.Forbidden);
            }

            return Mapper.Map<TransactionModel>(entity);
        }

        public override PagedResult<TransactionModel> GetPaged(TransactionSearchObject search)
        {
            var result = new List<TransactionModel>();

            var query = Context.Set<TransactionDb>().AsQueryable();

            query = AddFilter(search, query);

            int count = query.Count();
            var page = search?.GetSafePage() ?? 0;
            var pageSize = search?.GetSafePageSize() ?? 20;
            query = query.Skip(page * pageSize).Take(pageSize);

            var list = query.ToList();

            result = Mapper.Map(list, result);

            var pagedResult = new PagedResult<TransactionModel>();
            pagedResult.ResultList = result;
            pagedResult.Count = count;

            return pagedResult;
        }

        public Stripe.PaymentIntent CreatePaymentIntent(int coinsAmount)
        {
            if (coinsAmount <= 0) throw new UserException("Coins amount must be greater than 0");

            long amountInCents = (long)(coinsAmount * 100);

            var options = new Stripe.PaymentIntentCreateOptions
            {
                Amount = amountInCents,
                Currency = "bam",
                PaymentMethodTypes = new System.Collections.Generic.List<string> { "card" },
                Metadata = new System.Collections.Generic.Dictionary<string, string>
                {
                    { "userId", CurrentUserHelper.GetRequiredUserId(_httpContextAccessor).ToString() },
                    { "coinsAmount", coinsAmount.ToString() }
                }
            };

            var service = new Stripe.PaymentIntentService();
            var intent = service.Create(options);

            var transaction = new TransactionDb
            {
                UserId = CurrentUserHelper.GetRequiredUserId(_httpContextAccessor),
                Amount = coinsAmount,
                Currency = "BAM",
                PaymentMethod = "Stripe",
                Status = "Pending",
                StripePaymentIntentId = intent.Id,
                CreatedAt = DateTime.UtcNow
            };
            Context.Transactions.Add(transaction);
            Context.SaveChanges();

            return intent;
        }

        public Stripe.PaymentIntent CreatePaymentIntentForForm(int coinsAmount, int userId)
        {
            if (coinsAmount <= 0) throw new UserException("Coins amount must be greater than 0");
            if (userId <= 0) throw new UserException("Invalid user", System.Net.HttpStatusCode.Unauthorized);

            long amountInCents = (long)(coinsAmount * 100);

            var options = new Stripe.PaymentIntentCreateOptions
            {
                Amount = amountInCents,
                Currency = "bam",
                AutomaticPaymentMethods = new Stripe.PaymentIntentAutomaticPaymentMethodsOptions { Enabled = true },
                Metadata = new System.Collections.Generic.Dictionary<string, string>
                {
                    { "userId", userId.ToString() },
                    { "coinsAmount", coinsAmount.ToString() }
                }
            };

            var svc = new Stripe.PaymentIntentService();
            return svc.Create(options);
            // NOTE: No DB transaction created here. CompletePurchase creates it on confirmed payment.
        }

        public Stripe.Checkout.Session CreateCheckoutSession(int coinsAmount)
        {
            if (coinsAmount <= 0) throw new UserException("Coins amount must be greater than 0");

            var successUrl = "https://easypark-web.azurewebsites.net/payment-success?session_id={CHECKOUT_SESSION_ID}";
            var cancelUrl = "https://easypark-web.azurewebsites.net/payment-cancel";

            var request = _httpContextAccessor.HttpContext?.Request;
            if (request != null)
            {
                // Prefer the Origin/Referer header so the success page redirects back to the Flutter web app.
                var origin = request.Headers["Origin"].FirstOrDefault()
                    ?? request.Headers["Referer"].FirstOrDefault();

                if (!string.IsNullOrWhiteSpace(origin))
                {
                    // Strip trailing path from referer (keep scheme+host+port only).
                    if (Uri.TryCreate(origin, UriKind.Absolute, out var originUri))
                    {
                        var appBase = $"{originUri.Scheme}://{originUri.Authority}";
                        successUrl = $"{appBase}/?payment_success={{CHECKOUT_SESSION_ID}}";
                        cancelUrl = $"{appBase}/?payment_cancelled=true";
                    }
                }
                else if (request.Host.Host == "localhost" || request.Host.Host == "10.0.2.2" || request.Host.Host == "127.0.0.1")
                {
                    // Fallback for same-origin requests
                    var baseUrl = $"{request.Scheme}://{request.Host}";
                    successUrl = $"{baseUrl}/Transaction/success?session_id={{CHECKOUT_SESSION_ID}}";
                    cancelUrl = $"{baseUrl}/Transaction/cancel";
                }
            }

            var options = new Stripe.Checkout.SessionCreateOptions
            {
                PaymentMethodTypes = new System.Collections.Generic.List<string> { "card" },
                LineItems = new System.Collections.Generic.List<Stripe.Checkout.SessionLineItemOptions>
                {
                    new Stripe.Checkout.SessionLineItemOptions
                    {
                        PriceData = new Stripe.Checkout.SessionLineItemPriceDataOptions
                        {
                            UnitAmount = (long)(coinsAmount * 100),
                            Currency = "bam",
                            ProductData = new Stripe.Checkout.SessionLineItemPriceDataProductDataOptions
                            {
                                Name = $"{coinsAmount} EasyPark Coins",
                                Description = "Purchase coins for parking reservations",
                            },
                        },
                        Quantity = 1,
                    },
                },
                Mode = "payment",
                SuccessUrl = successUrl,
                CancelUrl = cancelUrl,
                Metadata = new System.Collections.Generic.Dictionary<string, string>
                {
                    { "userId", CurrentUserHelper.GetRequiredUserId(_httpContextAccessor).ToString() },
                    { "coinsAmount", coinsAmount.ToString() }
                }
            };

            var service = new Stripe.Checkout.SessionService();
            var session = service.Create(options);

            // Record pending transaction
            var transaction = new TransactionDb
            {
                UserId = CurrentUserHelper.GetRequiredUserId(_httpContextAccessor),
                Amount = coinsAmount,
                Currency = "BAM",
                PaymentMethod = "Stripe",
                Status = "Pending",
                StripeTransactionId = session.Id,
                StripePaymentIntentId = session.PaymentIntentId,
                CreatedAt = DateTime.UtcNow
            };
            Context.Transactions.Add(transaction);
            Context.SaveChanges();

            return session;
        }

        public TransactionModel CompletePurchase(string paymentIntentId)
        {
            if (string.IsNullOrWhiteSpace(paymentIntentId))
                throw new UserException("Payment reference is required", HttpStatusCode.BadRequest);
            if (paymentIntentId.StartsWith("cs_", StringComparison.Ordinal))
            {
                return CompletePurchaseByCheckoutSession(paymentIntentId);
            }

            // Fetch Stripe intent first (outside DB tx to avoid holding lock during network call).
            var intent = new Stripe.PaymentIntentService().Get(paymentIntentId);
            if (intent.Status != "succeeded")
                throw new UserException("Payment has not been confirmed by Stripe yet.", HttpStatusCode.BadRequest);

            using IDbContextTransaction dbTx = Context.Database.BeginTransaction(System.Data.IsolationLevel.Serializable);

            var transaction = Context.Transactions
                .OrderByDescending(t => t.Id)
                .FirstOrDefault(t => t.StripePaymentIntentId == paymentIntentId);

            if (transaction != null && transaction.Status == "Completed")
            {
                dbTx.Commit();
                return Mapper.Map<TransactionModel>(transaction);
            }

            if (transaction == null)
            {
                // Embedded form flow: no pre-created DB record. Resolve userId from Stripe metadata.
                int userId;
                if (intent.Metadata != null && intent.Metadata.TryGetValue("userId", out var uidStr) && int.TryParse(uidStr, out var parsedId))
                {
                    userId = parsedId;
                }
                else
                {
                    userId = CurrentUserHelper.GetRequiredUserId(_httpContextAccessor);
                }

                long coinsAmount = intent.AmountReceived / 100;
                transaction = new TransactionDb
                {
                    UserId = userId,
                    Amount = (decimal)coinsAmount,
                    Currency = "BAM",
                    PaymentMethod = "Stripe",
                    Status = "Pending",
                    StripePaymentIntentId = paymentIntentId,
                    CreatedAt = DateTime.UtcNow
                };
                Context.Transactions.Add(transaction);
                Context.SaveChanges();
            }

            ValidateAmountAndCurrency(transaction, intent.AmountReceived, intent.Currency);
            MarkTransactionCompleted(transaction);
            dbTx.Commit();
            return Mapper.Map<TransactionModel>(transaction);
        }

        public TransactionModel CompletePurchaseByCheckoutSession(string checkoutSessionId)
        {
            if (string.IsNullOrWhiteSpace(checkoutSessionId))
                throw new UserException("Checkout session reference is required", HttpStatusCode.BadRequest);

            var session = new Stripe.Checkout.SessionService().Get(checkoutSessionId);
            using IDbContextTransaction dbTx = Context.Database.BeginTransaction(System.Data.IsolationLevel.Serializable);

            var transaction = Context.Transactions
                .OrderByDescending(t => t.Id)
                .FirstOrDefault(t => t.StripeTransactionId == checkoutSessionId);

            if (transaction == null && !string.IsNullOrWhiteSpace(session.PaymentIntentId))
            {
                transaction = Context.Transactions
                    .OrderByDescending(t => t.Id)
                    .FirstOrDefault(t => t.StripePaymentIntentId == session.PaymentIntentId);
            }

            // Backward compatibility for older records that persisted session id in payment intent column.
            transaction ??= Context.Transactions
                .OrderByDescending(t => t.Id)
                .FirstOrDefault(t => t.StripePaymentIntentId == checkoutSessionId);

            if (transaction == null) throw new UserException("Transaction not found", HttpStatusCode.NotFound);
            if (transaction.Status == "Completed") return Mapper.Map<TransactionModel>(transaction);
            if (session.PaymentStatus != "paid") return Mapper.Map<TransactionModel>(transaction);

            ValidateAmountAndCurrency(transaction, session.AmountTotal ?? 0, session.Currency);
            transaction.StripeTransactionId = checkoutSessionId;
            if (!string.IsNullOrWhiteSpace(session.PaymentIntentId))
            {
                transaction.StripePaymentIntentId = session.PaymentIntentId;
            }

            MarkTransactionCompleted(transaction);
            dbTx.Commit();
            return Mapper.Map<TransactionModel>(transaction);
        }

        private void MarkTransactionCompleted(TransactionDb transaction)
        {
            transaction.Status = "Completed";
            transaction.PaymentDate = DateTime.UtcNow;

            var user = Context.Users.Find(transaction.UserId);
            if (user == null)
            {
                throw new UserException("User not found for transaction", HttpStatusCode.NotFound);
            }

            user.Coins += transaction.Amount;
            Context.SaveChanges();
        }

        private static void ValidateAmountAndCurrency(TransactionDb transaction, long amountInMinorUnits, string? stripeCurrency)
        {
            var expectedMinorUnits = (long)(transaction.Amount * 100);
            if (amountInMinorUnits != expectedMinorUnits)
            {
                throw new UserException("Payment amount mismatch", HttpStatusCode.BadRequest);
            }

            if (!string.Equals(stripeCurrency, transaction.Currency, StringComparison.OrdinalIgnoreCase))
            {
                throw new UserException("Payment currency mismatch", HttpStatusCode.BadRequest);
            }
        }

        public byte[] GenerateStripePaymentsPdf(bool allTime, int? year, int? month)
        {
            var currentUserId = CurrentUserHelper.GetRequiredUserId(_httpContextAccessor);
            var isAdmin = CurrentUserHelper.IsAdmin(_httpContextAccessor);
            var user = Context.Users.AsNoTracking().FirstOrDefault(u => u.Id == currentUserId)
                ?? throw new UserException("User not found", HttpStatusCode.NotFound);
            var displayName = isAdmin
                ? "All users"
                : $"{user.FirstName} {user.LastName}".Trim();
            if (string.IsNullOrEmpty(displayName))
                displayName = user.Username;

            IQueryable<TransactionDb> baseQuery = Context.Transactions.AsNoTracking();
            if (!isAdmin)
            {
                baseQuery = baseQuery.Where(t => t.UserId == currentUserId);
            }

            var query = baseQuery.Where(t => t.PaymentMethod == "Stripe");

            if (!allTime)
            {
                if (!year.HasValue || !month.HasValue || month is < 1 or > 12)
                    throw new UserException("Valid year and month are required when not using all-time export.", HttpStatusCode.BadRequest);

                var start = new DateTime(year.Value, month.Value, 1, 0, 0, 0, DateTimeKind.Utc);
                var end = start.AddMonths(1);
                query = query.Where(t =>
                    (t.PaymentDate ?? t.CreatedAt) >= start && (t.PaymentDate ?? t.CreatedAt) < end);
            }

            var list = query.OrderByDescending(t => t.PaymentDate ?? t.CreatedAt).ToList();
            if (list.Count == 0)
            {
                // Fallback: if there are no Stripe records in period, include other completed payments
                // so finance report still shows reservation-related revenue.
                var fallbackQuery = baseQuery.Where(t => t.Status == "Completed");
                if (!allTime)
                {
                    var start = new DateTime(year!.Value, month!.Value, 1, 0, 0, 0, DateTimeKind.Utc);
                    var end = start.AddMonths(1);
                    fallbackQuery = fallbackQuery.Where(t =>
                        (t.PaymentDate ?? t.CreatedAt) >= start && (t.PaymentDate ?? t.CreatedAt) < end);
                }
                list = fallbackQuery.OrderByDescending(t => t.PaymentDate ?? t.CreatedAt).ToList();
            }
            var period = allTime ? "All time" : $"{year:0000}-{month:00}";
            return StripePaymentsPdfDocument.Generate(list, displayName, period, DateTime.UtcNow);
        }
    }
}

