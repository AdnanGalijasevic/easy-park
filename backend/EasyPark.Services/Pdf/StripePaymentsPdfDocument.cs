using System;
using System.Collections.Generic;
using System.Linq;
using EasyPark.Services.Database;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace EasyPark.Services.Pdf
{
    public static class StripePaymentsPdfDocument
    {
        public static byte[] Generate(
            IList<Transaction> transactions,
            string userDisplayName,
            string periodTitle,
            DateTime generatedAtUtc)
        {
            var rows = transactions
                .OrderByDescending(t => t.PaymentDate ?? t.CreatedAt)
                .ToList();

            var total = rows.Where(t => t.Status == "Completed").Sum(t => t.Amount);

            return Document.Create(container =>
            {
                container.Page(page =>
                {
                    page.Margin(40);
                    page.DefaultTextStyle(x => x.FontSize(10));

                    page.Header().Column(c =>
                    {
                        c.Item().Text("EasyPark — Stripe payments").FontSize(18).SemiBold();
                        c.Item().PaddingTop(4).Text($"User: {userDisplayName}");
                        c.Item().Text($"Period: {periodTitle}");
                        c.Item().Text($"Generated: {generatedAtUtc:yyyy-MM-dd HH:mm} UTC").FontColor(Colors.Grey.Medium);
                    });

                    page.Content().PaddingVertical(16).Column(main =>
                    {
                        main.Item().Text($"Total completed (Stripe): {total:F2} BAM").SemiBold();

                        main.Item().PaddingTop(12).Table(t =>
                        {
                            t.ColumnsDefinition(cols =>
                            {
                                cols.RelativeColumn(2);
                                cols.RelativeColumn();
                                cols.RelativeColumn();
                                cols.RelativeColumn(2);
                            });

                            t.Header(h =>
                            {
                                static IContainer CellStyle(IContainer x) =>
                                    x.BorderBottom(1).BorderColor(Colors.Grey.Lighten2).PaddingVertical(4);

                                h.Cell().Element(CellStyle).Text("Date (UTC)").SemiBold();
                                h.Cell().Element(CellStyle).Text("Amount (BAM)").SemiBold();
                                h.Cell().Element(CellStyle).Text("Status").SemiBold();
                                h.Cell().Element(CellStyle).Text("Reference").SemiBold();
                            });

                            foreach (var tr in rows)
                            {
                                var dt = (tr.PaymentDate ?? tr.CreatedAt);
                                var refId = tr.StripePaymentIntentId ?? tr.StripeTransactionId ?? "—";
                                if (refId.Length > 28)
                                    refId = refId[..25] + "…";

                                t.Cell().BorderBottom(0.5f).BorderColor(Colors.Grey.Lighten3).PaddingVertical(3)
                                    .Text(dt.ToString("yyyy-MM-dd HH:mm"));
                                t.Cell().BorderBottom(0.5f).BorderColor(Colors.Grey.Lighten3).PaddingVertical(3)
                                    .Text($"{tr.Amount:F2}");
                                t.Cell().BorderBottom(0.5f).BorderColor(Colors.Grey.Lighten3).PaddingVertical(3)
                                    .Text(tr.Status);
                                t.Cell().BorderBottom(0.5f).BorderColor(Colors.Grey.Lighten3).PaddingVertical(3)
                                    .Text(refId);
                            }
                        });

                        if (rows.Count == 0)
                        {
                            main.Item().PaddingTop(16).Text("No Stripe payment records for this period.")
                                .Italic().FontColor(Colors.Grey.Medium);
                        }
                    });

                    page.Footer().AlignCenter().DefaultTextStyle(x => x.FontSize(8).FontColor(Colors.Grey.Medium))
                        .Text(t =>
                        {
                            t.Span("EasyPark — ");
                            t.CurrentPageNumber();
                            t.Span(" / ");
                            t.TotalPages();
                        });
                });
            }).GeneratePdf();
        }
    }
}
