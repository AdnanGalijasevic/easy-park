using EasyPark.Model.Models;
using EasyPark.Model.Requests;
using EasyPark.Model.SearchObjects;

namespace EasyPark.Services.Interfaces
{
    public interface ITransactionService : ICRUDService<Transaction, TransactionSearchObject, TransactionInsertRequest, TransactionUpdateRequest>
    {
        Stripe.PaymentIntent CreatePaymentIntent(int coinsAmount);
        /// <summary>Creates a PaymentIntent for the embedded form WITHOUT saving a DB transaction (saved on completion).</summary>
        Stripe.PaymentIntent CreatePaymentIntentForForm(int coinsAmount, int userId);
        Stripe.Checkout.Session CreateCheckoutSession(int coinsAmount);
        Transaction CompletePurchase(string paymentIntentId);
        Transaction CompletePurchaseByCheckoutSession(string checkoutSessionId);

        byte[] GenerateStripePaymentsPdf(bool allTime, int? year, int? month);
    }
}

