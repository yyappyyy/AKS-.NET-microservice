using ProductCatalog.Api.Endpoints;
using ProductCatalog.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// DI 登録
builder.Services.AddSingleton<IProductService, ProductService>();

// OpenAPI
builder.Services.AddOpenApi();

// ヘルスチェック
builder.Services.AddHealthChecks();

// CORS
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

// OpenAPI
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseCors();

// 静的ファイル配信 (wwwroot)
app.UseDefaultFiles();
app.UseStaticFiles();

// ヘルスチェックエンドポイント
app.MapHealthChecks("/healthz");
app.MapHealthChecks("/readyz");

// 商品カタログ API エンドポイント
app.MapProductEndpoints();

app.Run();

// テスト用に Program クラスを公開
public partial class Program { }
