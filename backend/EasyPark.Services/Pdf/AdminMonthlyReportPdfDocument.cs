using System;
using System.Collections.Generic;
using System.Linq;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace EasyPark.Services.Pdf
{
    public sealed class DailyPoint
    {
        public int Day { get; init; }
        public decimal Revenue { get; init; }
        public int Reservations { get; init; }
    }

    public static class AdminMonthlyReportPdfDocument
    {
        public static byte[] Generate(
            int year,
            int month,
            IReadOnlyList<DailyPoint> dailyPoints,
            decimal monthTotalRevenue,
            int monthTotalReservations,
            DateTime generatedAtUtc,
            bool graphsOnly = false)
        {
            var maxRev = dailyPoints.Count == 0 ? 1m : dailyPoints.Max(d => d.Revenue);
            if (maxRev <= 0) maxRev = 1m;
            var maxRes = dailyPoints.Count == 0 ? 1 : dailyPoints.Max(d => d.Reservations);
            if (maxRes <= 0) maxRes = 1;

            var title = graphsOnly
                ? $"EasyPark — Monthly charts {year:0000}-{month:00}"
                : $"EasyPark — Monthly report {year:0000}-{month:00}";

            return Document.Create(container =>
            {
                container.Page(page =>
                {
                    page.Margin(36);
                    page.DefaultTextStyle(x => x.FontSize(10));

                    page.Header().Column(c =>
                    {
                        c.Item().Text(title).FontSize(18).SemiBold();
                        c.Item().PaddingTop(4).Text($"Generated: {generatedAtUtc:yyyy-MM-dd HH:mm} UTC")
                            .FontColor(Colors.Grey.Medium);
                    });

                    page.Content().PaddingVertical(14).Column(main =>
                    {
                        if (!graphsOnly)
                        {
                            main.Item().Row(r =>
                            {
                                r.RelativeItem().Background(Colors.Grey.Lighten3).Padding(12).Column(col =>
                                {
                                    col.Item().Text("Total revenue (BAM)").FontSize(9).FontColor(Colors.Grey.Darken2);
                                    col.Item().Text($"{monthTotalRevenue:F2}").FontSize(20).SemiBold();
                                });
                                r.ConstantItem(12);
                                r.RelativeItem().Background(Colors.Grey.Lighten3).Padding(12).Column(col =>
                                {
                                    col.Item().Text("Completed reservations").FontSize(9).FontColor(Colors.Grey.Darken2);
                                    col.Item().Text($"{monthTotalReservations}").FontSize(20).SemiBold();
                                });
                            });
                        }

                        main.Item().PaddingTop(graphsOnly ? 0 : 18).Text("Revenue by day (chart)").FontSize(12).SemiBold();
                        main.Item().PaddingTop(6).Column(chart =>
                        {
                            foreach (var d in dailyPoints.OrderBy(x => x.Day))
                            {
                                var barW = Math.Max(4f, (float)((double)(d.Revenue / maxRev) * 220.0));
                                chart.Item().PaddingBottom(3).Row(row =>
                                {
                                    row.ConstantItem(36).Text($"{d.Day:00}");
                                    row.RelativeItem().Height(18).Background(Colors.Grey.Lighten2).Padding(2).Row(bar =>
                                    {
                                        bar.ConstantItem(barW).Height(14).Background("#2E7D32");
                                        bar.RelativeItem();
                                    });
                                    row.ConstantItem(72).AlignRight().Text($"{d.Revenue:F2}");
                                });
                            }
                            if (dailyPoints.Count == 0)
                                chart.Item().Text("No revenue in this month.").Italic().FontColor(Colors.Grey.Medium);
                        });

                        main.Item().PaddingTop(18).Text("Reservations by day (chart)").FontSize(12).SemiBold();
                        main.Item().PaddingTop(6).Column(chart =>
                        {
                            foreach (var d in dailyPoints.OrderBy(x => x.Day))
                            {
                                var barW = Math.Max(4f, (float)d.Reservations / maxRes * 220f);
                                chart.Item().PaddingBottom(3).Row(row =>
                                {
                                    row.ConstantItem(36).Text($"{d.Day:00}");
                                    row.RelativeItem().Height(18).Background(Colors.Grey.Lighten2).Padding(2).Row(bar =>
                                    {
                                        bar.ConstantItem(barW).Height(14).Background("#1565C0");
                                        bar.RelativeItem();
                                    });
                                    row.ConstantItem(48).AlignRight().Text($"{d.Reservations}");
                                });
                            }
                            if (dailyPoints.Count == 0)
                                chart.Item().Text("No reservations in this month.").Italic().FontColor(Colors.Grey.Medium);
                        });

                        if (!graphsOnly)
                        {
                            main.Item().PaddingTop(16).Text("Daily breakdown").FontSize(12).SemiBold();
                            main.Item().PaddingTop(6).Table(t =>
                            {
                                t.ColumnsDefinition(cols =>
                                {
                                    cols.ConstantColumn(40);
                                    cols.RelativeColumn();
                                    cols.RelativeColumn();
                                });

                                t.Header(h =>
                                {
                                    h.Cell().BorderBottom(1).PaddingVertical(4).Text("Day").SemiBold();
                                    h.Cell().BorderBottom(1).PaddingVertical(4).Text("Revenue (BAM)").SemiBold();
                                    h.Cell().BorderBottom(1).PaddingVertical(4).Text("Reservations").SemiBold();
                                });

                                foreach (var d in dailyPoints.OrderBy(x => x.Day))
                                {
                                    t.Cell().BorderBottom(0.5f).PaddingVertical(3).Text($"{d.Day:00}");
                                    t.Cell().BorderBottom(0.5f).PaddingVertical(3).Text($"{d.Revenue:F2}");
                                    t.Cell().BorderBottom(0.5f).PaddingVertical(3).Text($"{d.Reservations}");
                                }
                            });
                        }
                    });

                    page.Footer().AlignCenter().DefaultTextStyle(x => x.FontSize(8).FontColor(Colors.Grey.Medium))
                        .Text(t =>
                        {
                            t.Span("EasyPark Admin — ");
                            t.CurrentPageNumber();
                            t.Span(" / ");
                            t.TotalPages();
                        });
                });
            }).GeneratePdf();
        }
    }
}
