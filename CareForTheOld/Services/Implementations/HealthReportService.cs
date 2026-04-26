using CareForTheOld.Common.Constants;
using CareForTheOld.Data;
using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 健康报告服务实现
/// </summary>
public class HealthReportService : IHealthReportService
{
    private readonly AppDbContext _context;

    public HealthReportService(AppDbContext context) => _context = context;

    /// <summary>
    /// 生成健康报告 PDF
    /// </summary>
    public async Task<byte[]> GeneratePdfReportAsync(Guid userId, int daysRange)
    {
        // 获取用户信息
        var user = await _context.Users.FindAsync(userId)
            ?? throw new KeyNotFoundException(ErrorMessages.Common.UserNotFound);

        // 获取指定时间范围内的健康记录
        var startDate = DateTime.UtcNow.AddDays(-daysRange);
        var records = await _context.HealthRecords
            .Where(r => r.UserId == userId && !r.IsDeleted && r.RecordedAt >= startDate)
            .OrderByDescending(r => r.RecordedAt)
            .ToListAsync();

        // 生成 PDF
        QuestPDF.Settings.License = LicenseType.Community;

        var document = Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(PageSizes.A4);
                page.Margin(20, Unit.Millimetre);
                page.DefaultTextStyle(x => x.FontSize(12));

                // 封面
                page.Header().Element(element => CreateHeader(element, user, daysRange));

                // 内容
                page.Content().Element(element => CreateContent(element, user, records, daysRange));

                // 页脚
                page.Footer().AlignCenter().Text(x =>
                {
                    x.Span("关爱老人 App - 健康报告");
                    x.Span("  |  页码: ");
                    x.CurrentPageNumber();
                });
            });
        });

        return document.GeneratePdf();
    }

    /// <summary>
    /// 创建封面
    /// </summary>
    private static void CreateHeader(IContainer container, User user, int daysRange)
    {
        container.Column(column =>
        {
            column.Spacing(10);

            column.Item().AlignCenter().Text("健康数据报告")
                .FontSize(24).Bold().FontColor("#1976D2");

            column.Item().AlignCenter().Text($"用户: {user.RealName}")
                .FontSize(16);

            column.Item().AlignCenter().Text($"报告范围: 最近 {daysRange} 天")
                .FontSize(14).FontColor("#666666");

            column.Item().AlignCenter().Text($"生成时间: {DateTime.UtcNow:yyyy-MM-dd HH:mm}")
                .FontSize(12).FontColor("#666666");

            column.Item().PaddingTop(10).LineHorizontal(1).LineColor("#CCCCCC");
        });
    }

    /// <summary>
    /// 创建内容区域
    /// </summary>
    private static void CreateContent(IContainer container, User user, List<HealthRecord> records, int daysRange)
    {
        container.Column(column =>
        {
            column.Spacing(15);

            // 统计摘要
            column.Item().Element(element => CreateSummary(element, records));

            // 各类型详细数据
            foreach (HealthType type in Enum.GetValues(typeof(HealthType)))
            {
                var typeRecords = records.Where(r => r.Type == type).ToList();
                if (typeRecords.Count > 0)
                {
                    column.Item().Element(element => CreateTypeSection(element, type, typeRecords));
                }
            }

            // 建议区域
            column.Item().Element(element => CreateSuggestions(element, records));
        });
    }

    /// <summary>
    /// 创建统计摘要
    /// </summary>
    private static void CreateSummary(IContainer container, List<HealthRecord> records)
    {
        container.Column(column =>
        {
            column.Spacing(5);

            column.Item().Text("数据摘要")
                .FontSize(18).Bold().FontColor("#1565C0");

            column.Item().PaddingTop(5).LineHorizontal(0.5f).LineColor("#CCCCCC");

            // 汇总表格
            column.Item().Table(table =>
            {
                table.ColumnsDefinition(columns =>
                {
                    columns.RelativeColumn(2);
                    columns.RelativeColumn(1.5f);
                    columns.RelativeColumn(1.5f);
                    columns.RelativeColumn(1.5f);
                    columns.RelativeColumn(1);
                });

                // 表头
                table.Header(header =>
                {
                    header.Cell().Background("#E0E0E0").Padding(5).Text("类型").Bold();
                    header.Cell().Background("#E0E0E0").Padding(5).Text("记录数").Bold();
                    header.Cell().Background("#E0E0E0").Padding(5).Text("平均值").Bold();
                    header.Cell().Background("#E0E0E0").Padding(5).Text("最高值").Bold();
                    header.Cell().Background("#E0E0E0").Padding(5).Text("最低值").Bold();
                });

                // 各类型数据行
                foreach (HealthType type in Enum.GetValues(typeof(HealthType)))
                {
                    var typeRecords = records.Where(r => r.Type == type).ToList();
                    if (typeRecords.Count == 0) continue;

                    table.Cell().BorderBottom(0.5f).BorderColor("#BDBDBD").Padding(5).Text(GetTypeLabel(type));
                    table.Cell().BorderBottom(0.5f).BorderColor("#BDBDBD").Padding(5).Text(typeRecords.Count.ToString());

                    var (avg, max, min) = CalculateStats(type, typeRecords);
                    table.Cell().BorderBottom(0.5f).BorderColor("#BDBDBD").Padding(5).Text(avg);
                    table.Cell().BorderBottom(0.5f).BorderColor("#BDBDBD").Padding(5).Text(max);
                    table.Cell().BorderBottom(0.5f).BorderColor("#BDBDBD").Padding(5).Text(min);
                }
            });
        });
    }

    /// <summary>
    /// 创建各类型详细数据区域
    /// </summary>
    private static void CreateTypeSection(IContainer container, HealthType type, List<HealthRecord> records)
    {
        var typeColor = type == HealthType.BloodPressure ? "#C62828" :
            type == HealthType.BloodSugar ? "#1565C0" :
            type == HealthType.HeartRate ? "#6A1B9A" : "#E65100";

        container.Column(column =>
        {
            column.Spacing(5);

            column.Item().PaddingTop(10).Text($"{GetTypeLabel(type)}详细记录")
                .FontSize(16).Bold().FontColor(typeColor);

            column.Item().LineHorizontal(0.5f).LineColor("#CCCCCC");

            // 详细记录表格
            column.Item().Table(table =>
            {
                table.ColumnsDefinition(columns =>
                {
                    columns.RelativeColumn(2);
                    columns.RelativeColumn(2);
                    columns.RelativeColumn(3);
                });

                // 表头
                table.Header(header =>
                {
                    header.Cell().Background("#E0E0E0").Padding(5).Text("时间").Bold();
                    header.Cell().Background("#E0E0E0").Padding(5).Text("数值").Bold();
                    header.Cell().Background("#E0E0E0").Padding(5).Text("备注").Bold();
                });

                // 记录行（最多显示最近20条）
                foreach (var record in records.Take(20))
                {
                    var isAbnormal = IsAbnormal(type, record);
                    var backgroundColor = isAbnormal ? "#FFEBEE" : "#FFFFFF";
                    var valueColor = isAbnormal ? "#C62828" : "#000000";

                    table.Cell().Background(backgroundColor).BorderBottom(0.5f).BorderColor("#BDBDBD").Padding(5)
                        .Text(record.RecordedAt.ToLocalTime().ToString("MM-dd HH:mm"));
                    table.Cell().Background(backgroundColor).BorderBottom(0.5f).BorderColor("#BDBDBD").Padding(5)
                        .Text(GetRecordValue(type, record)).FontColor(valueColor);
                    table.Cell().Background(backgroundColor).BorderBottom(0.5f).BorderColor("#BDBDBD").Padding(5)
                        .Text(record.Note ?? "-");
                }
            });

            if (records.Count > 20)
            {
                column.Item().PaddingTop(5).AlignCenter().Text($"... 共 {records.Count} 条记录，仅显示最近 20 条")
                    .FontSize(10).FontColor("#666666");
            }
        });
    }

    /// <summary>
    /// 创建建议区域
    /// </summary>
    private static void CreateSuggestions(IContainer container, List<HealthRecord> records)
    {
        var suggestions = GenerateSuggestions(records);

        container.Column(column =>
        {
            column.Spacing(5);

            column.Item().PaddingTop(15).Text("健康建议")
                .FontSize(18).Bold().FontColor("#2E7D32");

            column.Item().LineHorizontal(0.5f).LineColor("#CCCCCC");

            foreach (var suggestion in suggestions)
            {
                column.Item().PaddingTop(5).Row(row =>
                {
                    row.Spacing(5);
                    row.ConstantItem(20).AlignCenter().Text("•").FontSize(14);
                    row.RelativeItem().Text(suggestion).FontSize(12);
                });
            }

            column.Item().PaddingTop(10).AlignCenter().Text("以上建议仅供参考，如有异常请及时就医。")
                .FontSize(10).FontColor("#666666");
        });
    }

    /// <summary>
    /// 计算统计数据
    /// </summary>
    private static (string avg, string max, string min) CalculateStats(HealthType type, List<HealthRecord> records)
    {
        switch (type)
        {
            case HealthType.BloodPressure:
                var systolicAvg = records.Average(r => r.Systolic ?? 0);
                var systolicMax = records.Max(r => r.Systolic ?? 0);
                var systolicMin = records.Min(r => r.Systolic ?? 0);
                return ($"{systolicAvg:F0} mmHg", $"{systolicMax} mmHg", $"{systolicMin} mmHg");

            case HealthType.BloodSugar:
                var bsAvg = records.Average(r => r.BloodSugar ?? 0);
                var bsMax = records.Max(r => r.BloodSugar ?? 0m);
                var bsMin = records.Min(r => r.BloodSugar ?? 0m);
                return ($"{bsAvg:F1} mmol/L", $"{bsMax:F1} mmol/L", $"{bsMin:F1} mmol/L");

            case HealthType.HeartRate:
                var hrAvg = records.Average(r => r.HeartRate ?? 0);
                var hrMax = records.Max(r => r.HeartRate ?? 0);
                var hrMin = records.Min(r => r.HeartRate ?? 0);
                return ($"{hrAvg:F0} 次/分", $"{hrMax} 次/分", $"{hrMin} 次/分");

            case HealthType.Temperature:
                var tempAvg = records.Average(r => r.Temperature ?? 0m);
                var tempMax = records.Max(r => r.Temperature ?? 0m);
                var tempMin = records.Min(r => r.Temperature ?? 0m);
                return ($"{tempAvg:F1} °C", $"{tempMax:F1} °C", $"{tempMin:F1} °C");

            default:
                return ("-", "-", "-");
        }
    }

    /// <summary>
    /// 获取类型标签
    /// </summary>
    private static string GetTypeLabel(HealthType type)
    {
        return type switch
        {
            HealthType.BloodPressure => "血压",
            HealthType.BloodSugar => "血糖",
            HealthType.HeartRate => "心率",
            HealthType.Temperature => "体温",
            _ => type.ToString()
        };
    }

    /// <summary>
    /// 获取记录值显示
    /// </summary>
    private static string GetRecordValue(HealthType type, HealthRecord record)
    {
        return type switch
        {
            HealthType.BloodPressure => $"{record.Systolic}/{record.Diastolic} mmHg",
            HealthType.BloodSugar => $"{record.BloodSugar:F1} mmol/L",
            HealthType.HeartRate => $"{record.HeartRate} 次/分",
            HealthType.Temperature => $"{record.Temperature:F1} °C",
            _ => "-"
        };
    }

    /// <summary>
    /// 判断数值是否异常
    /// </summary>
    private static bool IsAbnormal(HealthType type, HealthRecord record)
    {
        return type switch
        {
            HealthType.BloodPressure => (record.Systolic > 140 || record.Systolic < 90 ||
                                          record.Diastolic > 90 || record.Diastolic < 60),
            HealthType.BloodSugar => (record.BloodSugar > 6.1m || record.BloodSugar < 3.9m),
            HealthType.HeartRate => (record.HeartRate > 100 || record.HeartRate < 60),
            HealthType.Temperature => (record.Temperature > 37.3m || record.Temperature < 36.0m),
            _ => false
        };
    }

    /// <summary>
    /// 生成健康建议
    /// </summary>
    private static List<string> GenerateSuggestions(List<HealthRecord> records)
    {
        var suggestions = new List<string>();

        // 血压建议
        var bpRecords = records.Where(r => r.Type == HealthType.BloodPressure).ToList();
        if (bpRecords.Count > 0)
        {
            var avgSystolic = bpRecords.Average(r => r.Systolic ?? 0);
            if (avgSystolic > 140)
                suggestions.Add("血压偏高，建议减少盐分摄入，保持规律作息，必要时就医检查。");
            else if (avgSystolic < 90)
                suggestions.Add("血压偏低，建议适当增加营养，避免突然站立，必要时就医检查。");
            else
                suggestions.Add("血压在正常范围内，请继续保持良好的生活习惯。");
        }

        // 血糖建议
        var bsRecords = records.Where(r => r.Type == HealthType.BloodSugar).ToList();
        if (bsRecords.Count > 0)
        {
            var avgBs = bsRecords.Average(r => r.BloodSugar ?? 0m);
            if (avgBs > 6.1m)
                suggestions.Add("血糖偏高，建议控制饮食，减少糖分摄入，必要时就医检查。");
            else if (avgBs < 3.9m)
                suggestions.Add("血糖偏低，建议随身携带糖果，定时进餐，必要时就医检查。");
            else
                suggestions.Add("血糖在正常范围内，请继续保持健康的饮食习惯。");
        }

        // 心率建议
        var hrRecords = records.Where(r => r.Type == HealthType.HeartRate).ToList();
        if (hrRecords.Count > 0)
        {
            var avgHr = hrRecords.Average(r => r.HeartRate ?? 0);
            if (avgHr > 100)
                suggestions.Add("心率偏快，建议保持心情平和，适当运动，必要时就医检查。");
            else if (avgHr < 60)
                suggestions.Add("心率偏慢，如感到不适请及时就医检查。");
            else
                suggestions.Add("心率在正常范围内，请继续保持适度运动。");
        }

        // 体温建议
        var tempRecords = records.Where(r => r.Type == HealthType.Temperature).ToList();
        if (tempRecords.Count > 0)
        {
            var avgTemp = tempRecords.Average(r => r.Temperature ?? 0m);
            if (avgTemp > 37.3m)
                suggestions.Add("体温偏高，建议注意休息，多喝水，如持续发热请就医。");
            else if (avgTemp < 36.0m)
                suggestions.Add("体温偏低，建议注意保暖，适当增加衣物。");
            else
                suggestions.Add("体温正常，请继续保持良好的生活习惯。");
        }

        if (suggestions.Count == 0)
            suggestions.Add("暂无足够数据生成建议，请继续记录健康数据。");

        return suggestions;
    }
}