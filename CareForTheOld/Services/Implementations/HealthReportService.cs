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
    private static readonly HealthType[] AllHealthTypes = Enum.GetValues<HealthType>();
    private readonly AppDbContext _context;
    private readonly ILogger<HealthReportService> _logger;

    public HealthReportService(AppDbContext context, ILogger<HealthReportService> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// 生成健康报告 PDF
    /// </summary>
    public async Task<byte[]> GeneratePdfReportAsync(Guid userId, int daysRange, CancellationToken cancellationToken = default)
    {
        // 获取用户信息
        var user = await _context.Users.FindAsync([userId], cancellationToken)
            ?? throw new KeyNotFoundException(ErrorMessages.Common.UserNotFound);

        // 获取指定时间范围内的健康记录（限制上限，防止大数据量内存溢出）
        var startDate = DateTime.UtcNow.AddDays(-daysRange);
        var records = await _context.HealthRecords
            .Where(r => r.UserId == userId && !r.IsDeleted && r.RecordedAt >= startDate)
            .OrderByDescending(r => r.RecordedAt)
            .Take(AppConstants.HealthReport.MaxQueryRecords)
            .ToListAsync(cancellationToken);

        if (records.Count >= AppConstants.HealthReport.MaxQueryRecords)
        {
            _logger.LogWarning("用户 {UserId} 报告数据量已达上限，建议缩短时间范围", userId);
        }

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
                    x.Span(HealthReportMessages.FooterTitle);
                    x.Span(HealthReportMessages.FooterPageNumberPrefix);
                    x.CurrentPageNumber();
                });
            });
        });

        _logger.LogInformation("用户 {UserId} 生成健康报告 PDF，天数范围：{Days}，记录数：{Count}", userId, daysRange, records.Count);

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

            column.Item().AlignCenter().Text(HealthReportMessages.CoverTitle)
                .FontSize(24).Bold().FontColor(AppConstants.PdfColors.Text.TitleBlue);

            column.Item().AlignCenter().Text($"{HealthReportMessages.CoverUserPrefix}{user.RealName}")
                .FontSize(16);

            column.Item().AlignCenter().Text($"{HealthReportMessages.CoverRangePrefix}{daysRange}{HealthReportMessages.CoverRangeSuffix}")
                .FontSize(14).FontColor(AppConstants.PdfColors.Text.Secondary);

            column.Item().AlignCenter().Text($"{HealthReportMessages.CoverTimePrefix}{DateTime.UtcNow:yyyy-MM-dd HH:mm}")
                .FontSize(12).FontColor(AppConstants.PdfColors.Text.Secondary);

            column.Item().PaddingTop(10).LineHorizontal(1).LineColor(AppConstants.PdfColors.Border.Divider);
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

            // 各类型详细数据（使用 GroupBy 避免重复遍历）
            var recordsByType = records.GroupBy(r => r.Type).ToDictionary(g => g.Key, g => g.ToList());
            foreach (var type in AllHealthTypes)
            {
                if (recordsByType.TryGetValue(type, out var typeRecords) && typeRecords.Count > 0)
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

            column.Item().Text(HealthReportMessages.SummaryTitle)
                .FontSize(18).Bold().FontColor(AppConstants.PdfColors.Text.SummaryBlue);

            column.Item().PaddingTop(5).LineHorizontal(0.5f).LineColor(AppConstants.PdfColors.Border.Divider);

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
                    header.Cell().Background(AppConstants.PdfColors.Background.TableHeader).Padding(5).Text(HealthReportMessages.ColumnType).Bold();
                    header.Cell().Background(AppConstants.PdfColors.Background.TableHeader).Padding(5).Text(HealthReportMessages.ColumnRecordCount).Bold();
                    header.Cell().Background(AppConstants.PdfColors.Background.TableHeader).Padding(5).Text(HealthReportMessages.ColumnAverage).Bold();
                    header.Cell().Background(AppConstants.PdfColors.Background.TableHeader).Padding(5).Text(HealthReportMessages.ColumnMaximum).Bold();
                    header.Cell().Background(AppConstants.PdfColors.Background.TableHeader).Padding(5).Text(HealthReportMessages.ColumnMinimum).Bold();
                });

                // 各类型数据行
                foreach (var type in AllHealthTypes)
                {
                    var typeRecords = records.Where(r => r.Type == type).ToList();
                    if (!typeRecords.Any()) continue;

                    table.Cell().BorderBottom(0.5f).BorderColor(AppConstants.PdfColors.Border.TableCell).Padding(5).Text(type.GetLabel());
                    table.Cell().BorderBottom(0.5f).BorderColor(AppConstants.PdfColors.Border.TableCell).Padding(5).Text(typeRecords.Count.ToString());

                    var (avg, max, min) = CalculateStats(type, typeRecords);
                    table.Cell().BorderBottom(0.5f).BorderColor(AppConstants.PdfColors.Border.TableCell).Padding(5).Text(avg);
                    table.Cell().BorderBottom(0.5f).BorderColor(AppConstants.PdfColors.Border.TableCell).Padding(5).Text(max);
                    table.Cell().BorderBottom(0.5f).BorderColor(AppConstants.PdfColors.Border.TableCell).Padding(5).Text(min);
                }
            });
        });
    }

    /// <summary>
    /// 创建各类型详细数据区域
    /// </summary>
    private static void CreateTypeSection(IContainer container, HealthType type, List<HealthRecord> records)
    {
        var typeColor = type == HealthType.BloodPressure ? AppConstants.PdfColors.HealthType.BloodPressure :
            type == HealthType.BloodSugar ? AppConstants.PdfColors.HealthType.BloodSugar :
            type == HealthType.HeartRate ? AppConstants.PdfColors.HealthType.HeartRate : AppConstants.PdfColors.HealthType.Temperature;

        container.Column(column =>
        {
            column.Spacing(5);

            column.Item().PaddingTop(10).Text($"{type.GetLabel()}{HealthReportMessages.DetailRecordsSuffix}")
                .FontSize(16).Bold().FontColor(typeColor);

            column.Item().LineHorizontal(0.5f).LineColor(AppConstants.PdfColors.Border.Divider);

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
                    header.Cell().Background(AppConstants.PdfColors.Background.TableHeader).Padding(5).Text(HealthReportMessages.ColumnTime).Bold();
                    header.Cell().Background(AppConstants.PdfColors.Background.TableHeader).Padding(5).Text(HealthReportMessages.ColumnValue).Bold();
                    header.Cell().Background(AppConstants.PdfColors.Background.TableHeader).Padding(5).Text(HealthReportMessages.ColumnNote).Bold();
                });

                // 记录行（最多显示最近20条）
                foreach (var record in records.Take(AppConstants.HealthReport.MaxPdfRecords))
                {
                    var isAbnormal = IsAbnormal(type, record);
                    var backgroundColor = isAbnormal ? AppConstants.PdfColors.Background.AbnormalRow : AppConstants.PdfColors.Background.NormalRow;
                    var valueColor = isAbnormal ? AppConstants.PdfColors.HealthType.BloodPressure : AppConstants.PdfColors.Text.Normal;

                    table.Cell().Background(backgroundColor).BorderBottom(0.5f).BorderColor(AppConstants.PdfColors.Border.TableCell).Padding(5)
                        .Text(record.RecordedAt.ToLocalTime().ToString("MM-dd HH:mm"));
                    table.Cell().Background(backgroundColor).BorderBottom(0.5f).BorderColor(AppConstants.PdfColors.Border.TableCell).Padding(5)
                        .Text(GetRecordValue(type, record)).FontColor(valueColor);
                    table.Cell().Background(backgroundColor).BorderBottom(0.5f).BorderColor(AppConstants.PdfColors.Border.TableCell).Padding(5)
                        .Text(record.Note ?? "-");
                }
            });

            if (records.Count > AppConstants.HealthReport.MaxPdfRecords)
            {
                column.Item().PaddingTop(5).AlignCenter().Text(string.Format(HealthReportMessages.RecordsTruncatedTemplate, records.Count, AppConstants.HealthReport.MaxPdfRecords))
                    .FontSize(10).FontColor(AppConstants.PdfColors.Text.Secondary);
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

            column.Item().PaddingTop(15).Text(HealthReportMessages.SuggestionsTitle)
                .FontSize(18).Bold().FontColor(AppConstants.PdfColors.Text.SuggestionGreen);

            column.Item().LineHorizontal(0.5f).LineColor(AppConstants.PdfColors.Border.Divider);

            foreach (var suggestion in suggestions)
            {
                column.Item().PaddingTop(5).Row(row =>
                {
                    row.Spacing(5);
                    row.ConstantItem(20).AlignCenter().Text("•").FontSize(14);
                    row.RelativeItem().Text(suggestion).FontSize(12);
                });
            }

            column.Item().PaddingTop(10).AlignCenter().Text(HealthReportMessages.Disclaimer)
                .FontSize(10).FontColor(AppConstants.PdfColors.Text.Secondary);
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
                return ($"{systolicAvg:F0} {AppConstants.HealthUnits.BloodPressure}", $"{systolicMax} {AppConstants.HealthUnits.BloodPressure}", $"{systolicMin} {AppConstants.HealthUnits.BloodPressure}");

            case HealthType.BloodSugar:
                var bsAvg = records.Average(r => r.BloodSugar ?? 0);
                var bsMax = records.Max(r => r.BloodSugar ?? 0m);
                var bsMin = records.Min(r => r.BloodSugar ?? 0m);
                return ($"{bsAvg:F1} {AppConstants.HealthUnits.BloodSugar}", $"{bsMax:F1} {AppConstants.HealthUnits.BloodSugar}", $"{bsMin:F1} {AppConstants.HealthUnits.BloodSugar}");

            case HealthType.HeartRate:
                var hrAvg = records.Average(r => r.HeartRate ?? 0);
                var hrMax = records.Max(r => r.HeartRate ?? 0);
                var hrMin = records.Min(r => r.HeartRate ?? 0);
                return ($"{hrAvg:F0} {AppConstants.HealthUnits.HeartRate}", $"{hrMax} {AppConstants.HealthUnits.HeartRate}", $"{hrMin} {AppConstants.HealthUnits.HeartRate}");

            case HealthType.Temperature:
                var tempAvg = records.Average(r => r.Temperature ?? 0m);
                var tempMax = records.Max(r => r.Temperature ?? 0m);
                var tempMin = records.Min(r => r.Temperature ?? 0m);
                return ($"{tempAvg:F1} {AppConstants.HealthUnits.Temperature}", $"{tempMax:F1} {AppConstants.HealthUnits.Temperature}", $"{tempMin:F1} {AppConstants.HealthUnits.Temperature}");

            default:
                return ("-", "-", "-");
        }
    }

    /// <summary>
    /// 获取记录值显示
    /// </summary>
    private static string GetRecordValue(HealthType type, HealthRecord record)
    {
        return type switch
        {
            HealthType.BloodPressure => $"{record.Systolic}/{record.Diastolic} {AppConstants.HealthUnits.BloodPressure}",
            HealthType.BloodSugar => $"{record.BloodSugar:F1} {AppConstants.HealthUnits.BloodSugar}",
            HealthType.HeartRate => $"{record.HeartRate} {AppConstants.HealthUnits.HeartRate}",
            HealthType.Temperature => $"{record.Temperature:F1} {AppConstants.HealthUnits.Temperature}",
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
            HealthType.BloodPressure => (record.Systolic > AppConstants.HealthThresholds.BloodPressureSystolicMax ||
                                          record.Systolic < AppConstants.HealthThresholds.BloodPressureSystolicMin ||
                                          record.Diastolic > AppConstants.HealthThresholds.BloodPressureDiastolicMax ||
                                          record.Diastolic < AppConstants.HealthThresholds.BloodPressureDiastolicMin),
            HealthType.BloodSugar => (record.BloodSugar > AppConstants.HealthThresholds.BloodSugarMax ||
                                      record.BloodSugar < AppConstants.HealthThresholds.BloodSugarMin),
            HealthType.HeartRate => (record.HeartRate > AppConstants.HealthThresholds.HeartRateMax ||
                                     record.HeartRate < AppConstants.HealthThresholds.HeartRateMin),
            HealthType.Temperature => (record.Temperature > AppConstants.HealthThresholds.TemperatureMax ||
                                       record.Temperature < AppConstants.HealthThresholds.TemperatureMin),
            _ => false
        };
    }

    /// <summary>
    /// 生成健康建议
    /// </summary>
    private static List<string> GenerateSuggestions(List<HealthRecord> records)
    {
        var suggestions = new List<string>();

        AddThresholdSuggestion(suggestions, records, HealthType.BloodPressure,
            r => r.Systolic ?? 0,
            AppConstants.HealthThresholds.BloodPressureSystolicMax,
            AppConstants.HealthThresholds.BloodPressureSystolicMin,
            HealthReportMessages.Suggestions.BloodPressureHigh,
            HealthReportMessages.Suggestions.BloodPressureLow,
            HealthReportMessages.Suggestions.BloodPressureNormal);

        AddThresholdSuggestion(suggestions, records, HealthType.BloodSugar,
            r => (double)(r.BloodSugar ?? 0m),
            AppConstants.HealthThresholds.BloodSugarMax,
            AppConstants.HealthThresholds.BloodSugarMin,
            HealthReportMessages.Suggestions.BloodSugarHigh,
            HealthReportMessages.Suggestions.BloodSugarLow,
            HealthReportMessages.Suggestions.BloodSugarNormal);

        AddThresholdSuggestion(suggestions, records, HealthType.HeartRate,
            r => r.HeartRate ?? 0,
            AppConstants.HealthThresholds.HeartRateMax,
            AppConstants.HealthThresholds.HeartRateMin,
            HealthReportMessages.Suggestions.HeartRateHigh,
            HealthReportMessages.Suggestions.HeartRateLow,
            HealthReportMessages.Suggestions.HeartRateNormal);

        AddThresholdSuggestion(suggestions, records, HealthType.Temperature,
            r => (double)(r.Temperature ?? 0m),
            AppConstants.HealthThresholds.TemperatureMax,
            AppConstants.HealthThresholds.TemperatureMin,
            HealthReportMessages.Suggestions.TemperatureHigh,
            HealthReportMessages.Suggestions.TemperatureLow,
            HealthReportMessages.Suggestions.TemperatureNormal);

        if (!suggestions.Any())
            suggestions.Add(HealthReportMessages.Suggestions.NoData);

        return suggestions;
    }

    /// <summary>
    /// 通用的阈值建议生成方法：过滤指定类型的记录，计算平均值，与高/低阈值比较后添加建议
    /// </summary>
    private static void AddThresholdSuggestion(
        List<string> suggestions,
        List<HealthRecord> records,
        HealthType type,
        Func<HealthRecord, double> valueSelector,
        decimal highThreshold,
        decimal lowThreshold,
        string highMessage,
        string lowMessage,
        string normalMessage)
    {
        var typeRecords = records.Where(r => r.Type == type).ToList();
        if (!typeRecords.Any()) return;

        var avg = (decimal)typeRecords.Average(valueSelector);
        if (avg > highThreshold)
            suggestions.Add(highMessage);
        else if (avg < lowThreshold)
            suggestions.Add(lowMessage);
        else
            suggestions.Add(normalMessage);
    }
}