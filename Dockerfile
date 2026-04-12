# CareForTheOld 后端 API
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# 复制项目文件
COPY ["CareForTheOld/CareForTheOld.csproj", "CareForTheOld/"]
COPY ["CareForTheOld.Tests/CareForTheOld.Tests.csproj", "CareForTheOld.Tests/"]

# 还原依赖
RUN dotnet restore "CareForTheOld/CareForTheOld.csproj"

# 复制源代码
COPY CareForTheOld/ CareForTheOld/
COPY CareForTheOld.Tests/ CareForTheOld.Tests/

# 构建项目
WORKDIR "/src/CareForTheOld"
RUN dotnet build "CareForTheOld.csproj" -c Release -o /app/build

# 发布项目
FROM build AS publish
RUN dotnet publish "CareForTheOld.csproj" -c Release -o /app/publish /p:UseAppHost=false

# 运行阶段
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app

# 创建日志目录
RUN mkdir -p logs

# 复制发布文件
COPY --from=publish /app/publish .

# 设置环境变量
ENV ASPNETCORE_URLS=http://+:5000
ENV ASPNETCORE_ENVIRONMENT=Production

# 暴露端口
EXPOSE 5000

# 启动应用
ENTRYPOINT ["dotnet", "CareForTheOld.dll"]