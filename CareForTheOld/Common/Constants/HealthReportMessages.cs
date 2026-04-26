namespace CareForTheOld.Common.Constants;

/// <summary>
/// 健康报告 PDF 生成相关文本常量
/// 集中管理 PDF 报告中所有用户可见的中文字符串
/// </summary>
public static class HealthReportMessages
{
    /// <summary>页脚标题</summary>
    public const string FooterTitle = "关爱老人 App - 健康报告";

    /// <summary>页脚页码前缀</summary>
    public const string FooterPageNumberPrefix = "  |  页码: ";

    /// <summary>封面标题</summary>
    public const string CoverTitle = "健康数据报告";

    /// <summary>封面用户前缀</summary>
    public const string CoverUserPrefix = "用户: ";

    /// <summary>封面报告范围前缀</summary>
    public const string CoverRangePrefix = "报告范围: 最近 ";

    /// <summary>封面报告范围后缀</summary>
    public const string CoverRangeSuffix = " 天";

    /// <summary>封面生成时间前缀</summary>
    public const string CoverTimePrefix = "生成时间: ";

    /// <summary>数据摘要标题</summary>
    public const string SummaryTitle = "数据摘要";

    /// <summary>摘要表格 - 类型列标题</summary>
    public const string ColumnType = "类型";

    /// <summary>摘要表格 - 记录数列标题</summary>
    public const string ColumnRecordCount = "记录数";

    /// <summary>摘要表格 - 平均值列标题</summary>
    public const string ColumnAverage = "平均值";

    /// <summary>摘要表格 - 最高值列标题</summary>
    public const string ColumnMaximum = "最高值";

    /// <summary>摘要表格 - 最低值列标题</summary>
    public const string ColumnMinimum = "最低值";

    /// <summary>详细记录标题后缀</summary>
    public const string DetailRecordsSuffix = "详细记录";

    /// <summary>详细记录表格 - 时间列标题</summary>
    public const string ColumnTime = "时间";

    /// <summary>详细记录表格 - 数值列标题</summary>
    public const string ColumnValue = "数值";

    /// <summary>详细记录表格 - 备注列标题</summary>
    public const string ColumnNote = "备注";

    /// <summary>记录截断提示模板（占位符：总记录数、显示条数）</summary>
    public const string RecordsTruncatedTemplate = "... 共 {0} 条记录，仅显示最近 {1} 条";

    /// <summary>健康建议标题</summary>
    public const string SuggestionsTitle = "健康建议";

    /// <summary>免责声明</summary>
    public const string Disclaimer = "以上建议仅供参考，如有异常请及时就医。";

    /// <summary>
    /// 健康建议内容
    /// </summary>
    public static class Suggestions
    {
        // 血压建议
        public const string BloodPressureHigh = "血压偏高，建议减少盐分摄入，保持规律作息，必要时就医检查。";
        public const string BloodPressureLow = "血压偏低，建议适当增加营养，避免突然站立，必要时就医检查。";
        public const string BloodPressureNormal = "血压在正常范围内，请继续保持良好的生活习惯。";

        // 血糖建议
        public const string BloodSugarHigh = "血糖偏高，建议控制饮食，减少糖分摄入，必要时就医检查。";
        public const string BloodSugarLow = "血糖偏低，建议随身携带糖果，定时进餐，必要时就医检查。";
        public const string BloodSugarNormal = "血糖在正常范围内，请继续保持健康的饮食习惯。";

        // 心率建议
        public const string HeartRateHigh = "心率偏快，建议保持心情平和，适当运动，必要时就医检查。";
        public const string HeartRateLow = "心率偏慢，如感到不适请及时就医检查。";
        public const string HeartRateNormal = "心率在正常范围内，请继续保持适度运动。";

        // 体温建议
        public const string TemperatureHigh = "体温偏高，建议注意休息，多喝水，如持续发热请就医。";
        public const string TemperatureLow = "体温偏低，建议注意保暖，适当增加衣物。";
        public const string TemperatureNormal = "体温正常，请继续保持良好的生活习惯。";

        /// <summary>数据不足时的默认建议</summary>
        public const string NoData = "暂无足够数据生成建议，请继续记录健康数据。";
    }

    /// <summary>
    /// PDF 文件名相关
    /// </summary>
    public static class FileName
    {
        /// <summary>PDF 文件名前缀</summary>
        public const string Prefix = "健康报告";

        /// <summary>PDF 文件名日期格式</summary>
        public const string DateFormat = "yyyyMMdd";

        /// <summary>PDF 文件扩展名</summary>
        public const string Extension = ".pdf";
    }
}
