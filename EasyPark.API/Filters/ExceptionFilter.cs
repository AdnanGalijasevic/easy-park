using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
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
            _logger.LogError(context.Exception, context.Exception.Message);

            HttpStatusCode statusCode;
            string errorKey;

            if (context.Exception is UserException userException)
            {
                statusCode = userException.StatusCode;
                errorKey = "userError";
                context.ModelState.AddModelError(errorKey, context.Exception.Message);
            }
            else
            {
                statusCode = HttpStatusCode.InternalServerError;
                errorKey = "ERROR";
                context.ModelState.AddModelError(errorKey, "Server side error, please check logs");
            }

            context.HttpContext.Response.StatusCode = (int)statusCode;

            var list = context.ModelState.Where(x => x.Value!.Errors.Count() > 0)
                .ToDictionary(x => x.Key, y => y.Value!.Errors.Select(z => z.ErrorMessage));

            context.Result = new JsonResult(new { errors = list });
            context.ExceptionHandled = true;
        }
    }
}

