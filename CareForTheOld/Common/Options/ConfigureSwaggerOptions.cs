using Asp.Versioning.ApiExplorer;
using Microsoft.Extensions.Options;
using Microsoft.OpenApi;
using Swashbuckle.AspNetCore.SwaggerGen;

namespace CareForTheOld.Common.Options;

/// <summary>
/// 根据已注册的 API 版本自动配置 Swagger 文档
/// </summary>
public class ConfigureSwaggerOptions : IConfigureOptions<SwaggerGenOptions>
{
    private readonly IApiVersionDescriptionProvider _provider;

    public ConfigureSwaggerOptions(IApiVersionDescriptionProvider provider)
    {
        _provider = provider;
    }

    public void Configure(SwaggerGenOptions options)
    {
        // 为每个发现的 API 版本创建对应的 Swagger 文档
        foreach (var description in _provider.ApiVersionDescriptions)
        {
            options.SwaggerDoc(description.GroupName, new OpenApiInfo
            {
                Title = $"CareForTheOld API {description.ApiVersion}",
                Version = description.ApiVersion.ToString(),
                Description = "智慧助老平台 API 文档"
            });
        }
    }
}
