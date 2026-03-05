FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /app

# ソリューションとプロジェクトファイルをコピーしてリストア（キャッシュ活用）
COPY ProductCatalog.slnx ./
COPY src/ProductCatalog.Api/ProductCatalog.Api.csproj src/ProductCatalog.Api/
RUN dotnet restore src/ProductCatalog.Api/ProductCatalog.Api.csproj

# ソースコードをコピーしてビルド
COPY src/ src/
RUN dotnet publish src/ProductCatalog.Api/ProductCatalog.Api.csproj \
    -c Release \
    -o /app/publish

# ランタイムステージ
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

# non-root ユーザーで実行
USER $APP_UID

COPY --from=build /app/publish .

EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080

ENTRYPOINT ["dotnet", "ProductCatalog.Api.dll"]
