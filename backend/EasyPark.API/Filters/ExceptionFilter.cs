using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Http;
using System.Net;
using EasyPark.Model;

namespace EasyPark.API.Filters
{
    public class ExceptionFilter : ExceptionFilterAttribute
    {
        ILogger<ExceptionFilter> _logger;
        public ExceptionFilter(ILogger<ExceptionFilter> logger)
        {
            _logger = logger;
        }
        public override void OnException(ExceptionContext context)
        {
            var traceId = context.HttpContext.TraceIdentifier;
            var path = context.HttpContext.Request.Path.Value ?? string.Empty;
            var method = context.HttpContext.Request.Method;
            var queryString = context.HttpContext.Request.QueryString.Value ?? string.Empty;
            var userId = context.HttpContext.User?.FindFirst("UserId")?.Value
                ?? context.HttpContext.User?.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value
                ?? "anonymous";

            HttpStatusCode statusCode;
            string errorKey;
            string clientMessage;

            if (context.Exception is UserException userException)
            {
                statusCode = userException.StatusCode;
                errorKey = "userError";
                clientMessage = context.Exception.Message;
            }
            else
            {
                statusCode = HttpStatusCode.InternalServerError;
                errorKey = "error";
                clientMessage = "An unexpected server error occurred.";
            }

            context.ModelState.AddModelError(errorKey, clientMessage);
            context.HttpContext.Response.StatusCode = (int)statusCode;

            _logger.LogError(
                context.Exception,
                "Unhandled exception | TraceId:{TraceId} Method:{Method} Path:{Path} Query:{Query} User:{UserId} StatusCode:{StatusCode}",
                traceId,
                method,
                path,
                queryString,
                userId,
                (int)statusCode);

            var list = context.ModelState.Where(x => x.Value!.Errors.Count() > 0)
                .ToDictionary(x => x.Key, y => y.Value!.Errors.Select(z => z.ErrorMessage));

            context.Result = new JsonResult(new
            {
                traceId,
                message = clientMessage,
                userError = clientMessage,
                errors = list
            });
            context.ExceptionHandled = true;
        }
    }
}

