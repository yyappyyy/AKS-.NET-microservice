using ProductCatalog.Api.Models;
using ProductCatalog.Api.Services;

namespace ProductCatalog.Api.Endpoints;

public static class ProductEndpoints
{
    public static void MapProductEndpoints(this IEndpointRouteBuilder routes)
    {
        var group = routes.MapGroup("/api/products")
            .WithTags("Products");

        group.MapGet("/", (IProductService service, string? category) =>
        {
            var products = service.GetAll(category);
            return Results.Ok(products);
        })
        .WithName("GetAllProducts")
        .WithDescription("全商品を取得します。カテゴリでフィルタ可能です。");

        group.MapGet("/{id:guid}", (IProductService service, Guid id) =>
        {
            var product = service.GetById(id);
            return product is not null
                ? Results.Ok(product)
                : Results.NotFound(new { message = "商品が見つかりません。", id });
        })
        .WithName("GetProductById")
        .WithDescription("指定されたIDの商品を取得します。");

        group.MapPost("/", (IProductService service, CreateProductRequest request) =>
        {
            var product = service.Create(request);
            return Results.Created($"/api/products/{product.Id}", product);
        })
        .WithName("CreateProduct")
        .WithDescription("新しい商品を作成します。");

        group.MapPut("/{id:guid}", (IProductService service, Guid id, UpdateProductRequest request) =>
        {
            var product = service.Update(id, request);
            return product is not null
                ? Results.Ok(product)
                : Results.NotFound(new { message = "商品が見つかりません。", id });
        })
        .WithName("UpdateProduct")
        .WithDescription("指定されたIDの商品を更新します。");

        group.MapDelete("/{id:guid}", (IProductService service, Guid id) =>
        {
            var deleted = service.Delete(id);
            return deleted
                ? Results.NoContent()
                : Results.NotFound(new { message = "商品が見つかりません。", id });
        })
        .WithName("DeleteProduct")
        .WithDescription("指定されたIDの商品を削除します。");
    }
}
