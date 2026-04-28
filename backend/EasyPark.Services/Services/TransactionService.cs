using MapsterMapper;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using System;
using System.Linq;
using System.Net;
using Microsoft.EntityFrameworkCore.Storage;
using EasyPark.Model;
using EasyPark.Model.Constants;
using EasyPark.Model.Models;
using EasyPark.Model.Requests;
using EasyPark.Model.SearchObjects;
using EasyPark.Services.Database;
using EasyPark.Services.Helpers;
using EasyPark.Services.Interfaces;
using EasyPark.Services.Pdf;
using Microsoft.Extensions.Configuration;
using TransactionModel = EasyPark.Model.Models.Transaction;
using TransactionDb = EasyPark.Services.Database.Transaction;

namespace EasyPark.Services.Services
{
    public class TransactionService : BaseCRUDService<TransactionModel, TransactionSearchObject, TransactionDb, TransactionInsertRequest, TransactionUpdateRequest>, ITransactionService
    {
        private readonly IHttpContextAccessor _httpContextAccessor;
        private readonly INotificationService? _notificationService;
        private readonly HashSet<int> _allowedCoinPackages;
        private readonly string? _checkoutSuccessUrl;
        private readonly string? _checkoutCancelUrl;

        public TransactionService(EasyParkDbContext context, IMapper mapper, IHttpContextAccessor httpContextAccessor, IConfiguration? configuration = null, INotificationService? notificationService = null) : base(context, mapper)
        {
            _httpContextAccessor = httpContextAccessor;
            _notificationService = notificationService;
            _allowedCoinPackages = ParseAllowedCoinPackages(configuration?["Payments:AllowedCoinPackages"]);
            _checkoutSuccessUrl = configuration?["Payments:CheckoutSuccessUrl"];
            _checkoutCancelUrl = configuration?["Payments:CheckoutCancelUrl"];
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
            entity.Status = TransactionStatus.Pending;
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
                var validStatuses = new[] { TransactionStatus.Pending, TransactionStatus.Completed, TransactionStatus.Failed, TransactionStatus.Refunded };
                if (!validStatuses.Contains(request.Status))
                {
                    throw new UserException($"Invalid status. Valid statuses are: {string.Join(", ", validStatuses)}", HttpStatusCode.BadRequest);
                }

                if (request.Status == TransactionStatus.Completed && !entity.PaymentDate.HasValue)
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

        public StripePaymentResult CreatePaymentIntent(int coinsAmount)
        {
            var normalizedAmount = NormalizeAndValidateCoinsAmount(coinsAmount);
            var userId = CurrentUserHelper.GetRequiredUserId(_httpContextAccessor);
            EnsureNoOpenPendingCoinPayment(userId);

            long amountInCents = (long)(normalizedAmount * 100);

            var options = new Stripe.PaymentIntentCreateOptions
            {
                Amount = amountInCents,
                Currency = "bam",
                PaymentMethodTypes = new System.Collections.Generic.List<string> { "card" },
                Metadata = new System.Collections.Generic.Dictionary<string, string>
                {
                    { "userId", userId.ToString() },
                    { "coinsAmount", normalizedAmount.ToString() }
                }
            };

            var service = new Stripe.PaymentIntentService();
            var intent = service.Create(options);

            var transaction = new TransactionDb
            {
                UserId = CurrentUserHelper.GetRequiredUserId(_httpContextAccessor),
                Amount = normalizedAmount,
                Currency = "BAM",
                PaymentMethod = "Stripe",
                Status = TransactionStatus.Pending,
                StripePaymentIntentId = intent.Id,
                CreatedAt = DateTime.UtcNow
            };
            Context.Transactions.Add(transaction);
            Context.SaveChanges();

            return new StripePaymentResult
            {
                Id = intent.Id,
                ClientSecret = intent.ClientSecret,
                CoinsAmount = normalizedAmount,
                IsPaid = false
            };
        }

        public Stripe.PaymentIntent CreatePaymentIntentForForm(int coinsAmount)
        {
            var normalizedAmount = NormalizeAndValidateCoinsAmount(coinsAmount);
            var userId = CurrentUserHelper.GetRequiredUserId(_httpContextAccessor);
            EnsureNoOpenPendingCoinPayment(userId);

            long amountInCents = (long)(normalizedAmount * 100);

            var options = new Stripe.PaymentIntentCreateOptions
            {
                Amount = amountInCents,
                Currency = "bam",
                AutomaticPaymentMethods = new Stripe.PaymentIntentAutomaticPaymentMethodsOptions { Enabled = true },
                Metadata = new System.Collections.Generic.Dictionary<string, string>
                {
                    { "userId", userId.ToString() },
                    { "coinsAmount", normalizedAmount.ToString() }
                }
            };

            var svc = new Stripe.PaymentIntentService();
            return svc.Create(options);
        }

        public Stripe.Checkout.Session CreateCheckoutSession(int coinsAmount)
        {
            var normalizedAmount = NormalizeAndValidateCoinsAmount(coinsAmount);
            var userId = CurrentUserHelper.GetRequiredUserId(_httpContextAccessor);
            EnsureNoOpenPendingCoinPayment(userId);

            var successUrl = _checkoutSuccessUrl;
            var cancelUrl = _checkoutCancelUrl;

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
                else if (string.IsNullOrWhiteSpace(successUrl) || string.IsNullOrWhiteSpace(cancelUrl))
                {
                    var host = request.Host.Host;
                    if (host == "localhost" || host == "10.0.2.2" || host == "127.0.0.1")
                    {
                        // Local fallback for same-origin requests
                        var baseUrl = $"{request.Scheme}://{request.Host}";
                        successUrl = $"{baseUrl}/Transaction/success?session_id={{CHECKOUT_SESSION_ID}}";
                        cancelUrl = $"{baseUrl}/Transaction/cancel";
                    }
                }
            }

            if (string.IsNullOrWhiteSpace(successUrl) || string.IsNullOrWhiteSpace(cancelUrl))
            {
                throw new InvalidOperationException(
                    "Checkout return URLs are not configured. Set 'Payments:CheckoutSuccessUrl' and 'Payments:CheckoutCancelUrl' (or provide request origin).");
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
                            UnitAmount = (long)(normalizedAmount * 100),
                            Currency = "bam",
                            ProductData = new Stripe.Checkout.SessionLineItemPriceDataProductDataOptions
                            {
                                Name = $"{normalizedAmount} EasyPark Coins",
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
                    { "userId", userId.ToString() },
                    { "coinsAmount", normalizedAmount.ToString() }
                }
            };

            var service = new Stripe.Checkout.SessionService();
            var session = service.Create(options);

            var transaction = new TransactionDb
            {
                UserId = userId,
                Amount = normalizedAmount,
                Currency = "BAM",
                PaymentMethod = "Stripe",
                Status = TransactionStatus.Pending,
                StripeTransactionId = session.Id,
                StripePaymentIntentId = session.PaymentIntentId,
                CreatedAt = DateTime.UtcNow
            };
            Context.Transactions.Add(transaction);
            Context.SaveChanges();

            return session;
        }

        private int NormalizeAndValidateCoinsAmount(int coinsAmount)
        {
            if (coinsAmount <= 0)
            {
                throw new UserException("Coins amount must be greater than 0", HttpStatusCode.BadRequest);
            }

            if (!_allowedCoinPackages.Contains(coinsAmount))
            {
                var allowedList = string.Join(", ", _allowedCoinPackages.OrderBy(x => x));
                throw new UserException($"Invalid coin package. Allowed packages: {allowedList}", HttpStatusCode.BadRequest);
            }

            return coinsAmount;
        }

        private void EnsureNoOpenPendingCoinPayment(int userId)
        {
            var staleThreshold = DateTime.UtcNow.AddMinutes(-30);

            var stalePending = Context.Transactions
                .Where(t =>
                    t.UserId == userId &&
                    t.ReservationId == null &&
                    t.PaymentMethod == "Stripe" &&
                    t.Status == TransactionStatus.Pending &&
                    t.CreatedAt <= staleThreshold)
                .ToList();

            if (stalePending.Count > 0)
            {
                foreach (var tx in stalePending)
                {
                    tx.Status = TransactionStatus.Failed;
                }

                Context.SaveChanges();
            }

            var hasPending = Context.Transactions.Any(t =>
                t.UserId == userId &&
                t.ReservationId == null &&
                t.PaymentMethod == "Stripe" &&
                t.Status == TransactionStatus.Pending);

            if (hasPending)
            {
                throw new UserException(
                    "You already have a pending coin payment. Complete or cancel it before starting a new one.",
                    HttpStatusCode.Conflict);
            }
        }

        public int CancelPendingCoinPayments()
        {
            var userId = CurrentUserHelper.GetRequiredUserId(_httpContextAccessor);
            var pending = Context.Transactions
                .Where(t =>
                    t.UserId == userId &&
                    t.ReservationId == null &&
                    t.PaymentMethod == "Stripe" &&
                    t.Status == TransactionStatus.Pending)
                .ToList();

            if (pending.Count == 0)
            {
                return 0;
            }

            foreach (var tx in pending)
            {
                tx.Status = TransactionStatus.Failed;
            }

            Context.SaveChanges();
            return pending.Count;
        }

        private static HashSet<int> ParseAllowedCoinPackages(string? configured)
        {
            var values = (configured ?? "10,20,50,100")
                .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Select(v => int.TryParse(v, out var parsed) ? parsed : -1)
                .Where(v => v > 0)
                .ToHashSet();

            if (values.Count == 0)
            {
                return new HashSet<int> { 10, 20, 50, 100 };
            }

            return values;
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

            if (transaction != null && transaction.Status == TransactionStatus.Completed)
            {
                EnsureTransactionOwnership(transaction);
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

                if (!CurrentUserHelper.IsAdmin(_httpContextAccessor) &&
                    userId != CurrentUserHelper.GetRequiredUserId(_httpContextAccessor))
                {
                    throw new UserException("Forbidden", HttpStatusCode.Forbidden);
                }

                long coinsAmount = intent.AmountReceived / 100;
                transaction = new TransactionDb
                {
                    UserId = userId,
                    Amount = (decimal)coinsAmount,
                    Currency = "BAM",
                    PaymentMethod = "Stripe",
                Status = TransactionStatus.Pending,
                StripePaymentIntentId = paymentIntentId,
                    CreatedAt = DateTime.UtcNow
                };
                Context.Transactions.Add(transaction);
                Context.SaveChanges();
            }
            else
            {
                EnsureTransactionOwnership(transaction);
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
            EnsureTransactionOwnership(transaction);
            if (transaction.Status == TransactionStatus.Completed) return Mapper.Map<TransactionModel>(transaction);
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

        public void CompletePurchaseByPaymentIntentId(string paymentIntentId)
        {
            if (string.IsNullOrWhiteSpace(paymentIntentId))
                return;

            using IDbContextTransaction dbTx = Context.Database.BeginTransaction(System.Data.IsolationLevel.Serializable);

            var transaction = Context.Transactions
                .OrderByDescending(t => t.Id)
                .FirstOrDefault(t => t.StripePaymentIntentId == paymentIntentId);

            if (transaction == null || transaction.Status == "Completed")
            {
                dbTx.Commit();
                return;
            }

            MarkTransactionCompleted(transaction);
            dbTx.Commit();
        }

        private void MarkTransactionCompleted(TransactionDb transaction)
        {
            transaction.Status = TransactionStatus.Completed;
            transaction.PaymentDate = DateTime.UtcNow;

            var user = Context.Users.Find(transaction.UserId);
            if (user == null)
            {
                throw new UserException("User not found for transaction", HttpStatusCode.NotFound);
            }

            user.Coins += transaction.Amount;
            Context.SaveChanges();

            _notificationService?.CreateNotification(
                transaction.UserId,
                "Payment Successful",
                $"Payment of {transaction.Amount} coins completed successfully.",
                "Success");
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

        private void EnsureTransactionOwnership(TransactionDb transaction)
        {
            if (CurrentUserHelper.IsAdmin(_httpContextAccessor))
            {
                return;
            }

            var currentUserId = CurrentUserHelper.GetRequiredUserId(_httpContextAccessor);
            if (transaction.UserId != currentUserId)
            {
                throw new UserException("Forbidden", HttpStatusCode.Forbidden);
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
                var fallbackQuery = baseQuery.Where(t => t.Status == TransactionStatus.Completed);
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

