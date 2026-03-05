using ProductCatalog.Api.Endpoints;
using ProductCatalog.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// DI 登録
builder.Services.AddSingleton<IProductService, ProductService>();

// OpenAPI (Swagger)
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

// OpenAPI は開発環境のみ
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseCors();

// ヘルスチェックエンドポイント
app.MapHealthChecks("/healthz");
app.MapHealthChecks("/readyz");

// 商品カタログ API エンドポイント
app.MapProductEndpoints();

app.Run();

// テスト用に Program クラスを公開
public partial class Program { }
