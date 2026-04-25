using EasyPark.Model;
using EasyPark.Model.Models;
using EasyPark.Model.Requests;
using EasyPark.Model.SearchObjects;
using EasyPark.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Stripe;
using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace EasyPark.API.Controllers
{
    [ApiController]
    [Route("[controller]")]
    [Authorize]
    public class TransactionController : BaseCRUDController<Transaction, TransactionSearchObject, TransactionInsertRequest, TransactionUpdateRequest>
    {
        protected new ITransactionService _service;
        private readonly IConfiguration _configuration;

        public TransactionController(ITransactionService service, IConfiguration configuration) : base(service)
        {
            _service = service;
            _configuration = configuration;
        }

        [HttpGet]
        public override PagedResult<Transaction> GetList([FromQuery] TransactionSearchObject searchObject)
        {
            return _service.GetPaged(searchObject);
        }

        [HttpGet("{id}")]
        public override Transaction GetById(int id)
        {
            return _service.GetById(id);
        }

        [Authorize(Roles = "Admin")]
        [HttpPost]
        public override Transaction Insert(TransactionInsertRequest request)
        {
            return _service.Insert(request);
        }

        [Authorize(Roles = "Admin")]
        [HttpPut("{id}")]
        public override Transaction Update(int id, TransactionUpdateRequest request)
        {
            return _service.Update(id, request);
        }

        [Authorize(Roles = "Admin")]
        [HttpDelete("{id}")]
        public override IActionResult Delete(int id)
        {
            return base.Delete(id);
        }

        [HttpGet("stripe-payments-pdf")]
        public IActionResult DownloadStripePaymentsPdf([FromQuery] bool allTime = false, [FromQuery] int? year = null,
            [FromQuery] int? month = null)
        {
            var pdf = _service.GenerateStripePaymentsPdf(allTime, year, month);
            var fileName = allTime
                ? "easypark-stripe-payments-all-time.pdf"
                : $"easypark-stripe-payments-{year:0000}-{month:00}.pdf";
            return File(pdf, "application/pdf", fileName);
        }

        [HttpPost("buy-coins")]
        public Stripe.PaymentIntent BuyCoins([FromQuery] int amount)
        {
            return _service.CreatePaymentIntent(amount);
        }

        [HttpPost("create-checkout-session")]
        public Stripe.Checkout.Session CreateCheckoutSession([FromQuery] int amount)
        {
            return _service.CreateCheckoutSession(amount);
        }

        [HttpPost("complete-purchase")]
        public Transaction CompletePurchase([FromQuery] string paymentIntentId)
        {
            return _service.CompletePurchase(paymentIntentId);
        }

        /// <summary>
        /// Returns a self-contained HTML page with embedded Stripe Elements card form.
        /// The page creates a PaymentIntent, collects card details via Stripe.js, confirms payment,
        /// then calls complete-purchase and posts a postMessage to the parent Flutter frame.
        /// </summary>
        [HttpGet("payment-form")]
        [AllowAnonymous]
        public ContentResult GetPaymentForm([FromQuery] int amount, [FromQuery] string? token)
        {
            if (amount <= 0)
                return new ContentResult { StatusCode = 400, Content = "Amount must be > 0" };

            var publishableKey = Environment.GetEnvironmentVariable("_stripePublishableKey");
            if (string.IsNullOrWhiteSpace(publishableKey))
            {
                publishableKey = _configuration["Stripe:PublishableKey"];
            }
            if (string.IsNullOrWhiteSpace(publishableKey))
            {
                return new ContentResult
                {
                    StatusCode = 500,
                    ContentType = "text/plain",
                    Content = "Stripe publishable key is missing. Set _stripePublishableKey or Stripe:PublishableKey."
                };
            }

            // Decode userId from the JWT token passed as query param (endpoint is AllowAnonymous).
            int userId = 0;
            if (!string.IsNullOrWhiteSpace(token))
            {
                try
                {
                    var handler = new System.IdentityModel.Tokens.Jwt.JwtSecurityTokenHandler();
                    var jwt = handler.ReadJwtToken(token);
                    var sidClaim = jwt.Claims.FirstOrDefault(c => c.Type == "nameid" || c.Type == System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
                    if (sidClaim != null) int.TryParse(sidClaim, out userId);
                }
                catch { /* invalid token — userId stays 0, CreatePaymentIntentForForm will throw */ }
            }

            var intent = _service.CreatePaymentIntentForForm(amount, userId);
            var clientSecret = intent.ClientSecret;
            var backendOrigin = $"{Request.Scheme}://{Request.Host}";

            var html = $@"<!DOCTYPE html>
<html lang=""en"">
<head>
<meta charset=""UTF-8"">
<meta name=""viewport"" content=""width=device-width,initial-scale=1"">
<title>Pay with Card</title>
<script src=""https://js.stripe.com/v3/""></script>
<style>
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{ font-family: 'Segoe UI', sans-serif; background: #1a1a2e; color: #e0e0e0; display: flex; align-items: center; justify-content: center; min-height: 100vh; padding: 16px; }}
  .card {{ background: #16213e; border-radius: 16px; padding: 32px 28px; width: 100%; max-width: 420px; box-shadow: 0 8px 32px rgba(0,0,0,0.4); }}
  h2 {{ color: #F47920; margin-bottom: 6px; font-size: 22px; }}
  .subtitle {{ color: #aaa; margin-bottom: 24px; font-size: 14px; }}
  .amount-badge {{ background: #F4792020; border: 1px solid #F47920; color: #F47920; padding: 8px 16px; border-radius: 8px; display: inline-block; margin-bottom: 24px; font-size: 18px; font-weight: bold; }}
  #payment-element {{ margin-bottom: 20px; }}
  #submit {{ background: #F47920; color: white; border: none; padding: 14px; border-radius: 8px; width: 100%; font-size: 16px; font-weight: bold; cursor: pointer; transition: background 0.2s; }}
  #submit:hover:not(:disabled) {{ background: #E56C15; }}
  #submit:disabled {{ opacity: 0.6; cursor: not-allowed; }}
  #error-msg {{ color: #ff6b6b; margin-top: 12px; font-size: 13px; min-height: 20px; }}
  #success-view {{ display: none; text-align: center; padding: 20px 0; }}
  #success-view .icon {{ font-size: 56px; color: #F47920; margin-bottom: 16px; }}
  #success-view h3 {{ color: #F47920; font-size: 20px; }}
  #success-view p {{ color: #aaa; margin-top: 8px; }}
  .spinner {{ display: inline-block; width: 18px; height: 18px; border: 2px solid #fff; border-top-color: transparent; border-radius: 50%; animation: spin 0.7s linear infinite; vertical-align: middle; margin-right: 8px; }}
  @keyframes spin {{ to {{ transform: rotate(360deg); }} }}
</style>
</head>
<body>
<div class=""card"">
  <h2>Top Up Coins</h2>
  <p class=""subtitle"">Secure payment via Stripe</p>
  <div class=""amount-badge"">{amount} Coins = {amount}.00 BAM</div>
  <form id=""payment-form"">
    <div id=""payment-element""></div>
    <button id=""submit"" type=""submit"">Pay {amount}.00 BAM</button>
    <div id=""error-msg""></div>
  </form>
  <div id=""success-view"">
    <div class=""icon"">✓</div>
    <h3>Payment Successful!</h3>
    <p>{amount} coins added to your account.</p>
  </div>
</div>
<script>
const stripe = Stripe('{publishableKey}');
const elements = stripe.elements({{ clientSecret: '{clientSecret}', appearance: {{ theme: 'night', variables: {{ colorPrimary: '#F47920' }} }} }});
const paymentElement = elements.create('payment');
paymentElement.mount('#payment-element');

const form = document.getElementById('payment-form');
const submitBtn = document.getElementById('submit');
const errorMsg = document.getElementById('error-msg');
const authToken = new URLSearchParams(window.location.search).get('token') || '';
paymentElement.on('loaderror', (ev) => {{
  const msg = ev?.error?.message || 'Payment form failed to load.';
  errorMsg.textContent = msg + ' Check that Stripe secret key and publishable key belong to same Stripe account.';
}});

form.addEventListener('submit', async (e) => {{
  e.preventDefault();
  submitBtn.disabled = true;
  submitBtn.innerHTML = '<span class=""spinner""></span>Processing...';
  errorMsg.textContent = '';

  const result = await stripe.confirmPayment({{
    elements,
    redirect: 'if_required',
  }});

  if (result.error) {{
    errorMsg.textContent = result.error.message;
    submitBtn.disabled = false;
    submitBtn.textContent = 'Pay {amount}.00 BAM';
    return;
  }}

  // Payment confirmed by Stripe.js — now call backend to record coins
  const paymentIntentId = result.paymentIntent.id;
  try {{
    const headers = authToken ? {{ 'Authorization': 'Bearer ' + authToken }} : {{}};
    const resp = await fetch('{backendOrigin}/Transaction/complete-purchase?paymentIntentId=' + paymentIntentId, {{
      method: 'POST',
      headers
    }});
    if (!resp.ok) throw new Error('Backend error ' + resp.status);
  }} catch(err) {{
    console.warn('complete-purchase failed:', err);
    // Still notify parent — backend can be retried via refresh
  }}

  document.getElementById('payment-form').style.display = 'none';
  document.getElementById('success-view').style.display = 'block';

  // Notify parent Flutter frame
  const msg = {{ type: 'STRIPE_PAYMENT_SUCCESS', paymentIntentId, coinsAmount: {amount} }};
  if (window.parent && window.parent !== window) {{
    window.parent.postMessage(msg, '*');
  }}
}});
</script>
</body>
</html>";

            return new ContentResult
            {
                ContentType = "text/html",
                StatusCode = 200,
                Content = html
            };
        }

        [AllowAnonymous]
        [HttpPost("stripe-webhook")]
        public async Task<IActionResult> StripeWebhook()
        {
            var webhookSecret = Environment.GetEnvironmentVariable("_stripeWebhookSecret")
                ?? throw new InvalidOperationException("Stripe webhook secret is not configured. Set '_stripeWebhookSecret'.");

            string json;
            using (var reader = new StreamReader(HttpContext.Request.Body))
            {
                json = await reader.ReadToEndAsync();
            }

            var signatureHeader = Request.Headers["Stripe-Signature"];
            Event stripeEvent;
            try
            {
                stripeEvent = EventUtility.ConstructEvent(json, signatureHeader, webhookSecret);
            }
            catch (StripeException)
            {
                return BadRequest();
            }

            if (stripeEvent.Type == "checkout.session.completed")
            {
                if (stripeEvent.Data.Object is Stripe.Checkout.Session checkoutSession && !string.IsNullOrWhiteSpace(checkoutSession.Id))
                {
                    _service.CompletePurchaseByCheckoutSession(checkoutSession.Id);
                }
            }

            return Ok();
        }

        [AllowAnonymous]
        [HttpGet("success")]
        public ContentResult Success([FromQuery] string? session_id)
        {
            var sessionJs = string.IsNullOrWhiteSpace(session_id) ? "null" : $"'{session_id}'";
            var html = $@"
<html>
<head>
    <style>
        body {{ font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f7f6; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }}
        .card {{ background: white; padding: 40px; border-radius: 12px; box-shadow: 0 4px 20px rgba(0,0,0,0.1); text-align: center; max-width: 400px; width: 90%; }}
        h1 {{ color: #86B94E; margin-bottom: 10px; }}
        p {{ color: #666; margin-bottom: 30px; }}
        .btn {{ background-color: #86B94E; color: white; border: none; padding: 12px 24px; border-radius: 6px; font-size: 16px; font-weight: bold; cursor: pointer; text-decoration: none; display: inline-block; }}
        .btn:hover {{ background-color: #75a343; }}
    </style>
</head>
<body>
    <div class='card'>
        <div id='icon' style='font-size: 60px; color: #86B94E; margin-bottom: 20px;'>⏳</div>
        <h1 id='title'>Processing...</h1>
        <p id='msg'>Confirming your payment. Please wait.</p>
        <div id='actions' style='display:none'>
            <button onclick='returnToApp()' class='btn'>Return to App</button>
        </div>
    </div>
    <script>
        var SESSION_ID = {sessionJs};
        var RETURN_URL = 'easypark://payment-success?session_id=' + (SESSION_ID || '');

        function returnToApp() {{
            window.location.href = RETURN_URL;
        }}

        function showSuccess() {{
            document.getElementById('icon').textContent = '✓';
            document.getElementById('title').textContent = 'Payment Successful!';
            document.getElementById('msg').textContent = 'Your coins have been added to your account.';
            document.getElementById('actions').style.display = 'block';
            setTimeout(returnToApp, 2000);
        }}

        function showError(msg) {{
            document.getElementById('icon').textContent = '⚠';
            document.getElementById('icon').style.color = '#e67e22';
            document.getElementById('title').textContent = 'Payment Received';
            document.getElementById('msg').textContent = msg || 'Payment received. Open the app and refresh your balance.';
            document.getElementById('actions').style.display = 'block';
            setTimeout(returnToApp, 3000);
        }}

        if (SESSION_ID) {{
            setTimeout(returnToApp, 2500);
            showSuccess();
        }} else {{
            showError('No session ID found. Return to app and refresh your balance.');
        }}
    </script>
</body>
</html>";
            return new ContentResult
            {
                ContentType = "text/html",
                StatusCode = (int)System.Net.HttpStatusCode.OK,
                Content = html
            };
        }

        [AllowAnonymous]
        [HttpGet("cancel")]
        public ContentResult Cancel()
        {
            return new ContentResult
            {
                ContentType = "text/html",
                StatusCode = (int)System.Net.HttpStatusCode.OK,
                Content = @"
<html>
<head>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f7f6; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
        .card { background: white; padding: 40px; border-radius: 12px; box-shadow: 0 4px 20px rgba(0,0,0,0.1); text-align: center; max-width: 400px; width: 90%; }
        h1 { color: #e74c3c; margin-bottom: 10px; }
        p { color: #666; margin-bottom: 30px; }
        .btn { background-color: #e74c3c; color: white; border: none; padding: 12px 24px; border-radius: 6px; font-size: 16px; font-weight: bold; cursor: pointer; text-decoration: none; display: inline-block; }
        .btn:hover { background-color: #c0392b; }
    </style>
</head>
<body>
    <div class='card'>
        <div style='font-size: 60px; color: #e74c3c; margin-bottom: 20px;'>✕</div>
        <h1>Payment Cancelled</h1>
        <p>The payment process was cancelled. No charges were made. You can close this tab and try again.</p>
        <button onclick='window.close()' class='btn'>Close Tab</button>
        <div style='margin-top: 20px;'><a href='easypark://payment-cancel' style='color: #e74c3c; text-decoration: none; font-size: 14px;'>Return to App</a></div>
    </div>
</body>
</html>"
            };
        }
    }
}

