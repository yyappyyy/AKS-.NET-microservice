using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using ProductCatalog.Api.Models;

namespace ProductCatalog.Api.Tests.Endpoints;

public class ProductEndpointsTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public ProductEndpointsTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task GetAll_ReturnsOkWithList()
    {
        var response = await _client.GetAsync("/api/products");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var products = await response.Content.ReadFromJsonAsync<List<Product>>();
        Assert.NotNull(products);
    }

    [Fact]
    public async Task CreateProduct_ReturnsCreated()
    {
        var request = new CreateProductRequest
        {
            Name = "テスト商品",
            Description = "テスト説明",
            Price = 1000m,
            Category = "テストカテゴリ"
        };

        var response = await _client.PostAsJsonAsync("/api/products", request);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var product = await response.Content.ReadFromJsonAsync<Product>();
        Assert.NotNull(product);
        Assert.Equal("テスト商品", product.Name);
        Assert.Equal(1000m, product.Price);
        Assert.NotEqual(Guid.Empty, product.Id);
    }

    [Fact]
    public async Task GetById_ReturnsNotFound_WhenProductDoesNotExist()
    {
        var response = await _client.GetAsync($"/api/products/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task CreateAndGetById_ReturnsProduct()
    {
        var request = new CreateProductRequest
        {
            Name = "取得テスト商品",
            Description = "説明",
            Price = 500m,
            Category = "カテゴリA"
        };

        var createResponse = await _client.PostAsJsonAsync("/api/products", request);
        var created = await createResponse.Content.ReadFromJsonAsync<Product>();
        Assert.NotNull(created);

        var getResponse = await _client.GetAsync($"/api/products/{created.Id}");

        Assert.Equal(HttpStatusCode.OK, getResponse.StatusCode);
        var product = await getResponse.Content.ReadFromJsonAsync<Product>();
        Assert.NotNull(product);
        Assert.Equal(created.Id, product.Id);
        Assert.Equal("取得テスト商品", product.Name);
    }

    [Fact]
    public async Task UpdateProduct_ReturnsUpdatedProduct()
    {
        var createRequest = new CreateProductRequest
        {
            Name = "更新前商品",
            Description = "更新前",
            Price = 100m,
            Category = "カテゴリB"
        };
        var createResponse = await _client.PostAsJsonAsync("/api/products", createRequest);
        var created = await createResponse.Content.ReadFromJsonAsync<Product>();
        Assert.NotNull(created);

        var updateRequest = new UpdateProductRequest
        {
            Name = "更新後商品",
            Description = "更新後",
            Price = 200m,
            Category = "カテゴリC"
        };

        var updateResponse = await _client.PutAsJsonAsync($"/api/products/{created.Id}", updateRequest);

        Assert.Equal(HttpStatusCode.OK, updateResponse.StatusCode);
        var updated = await updateResponse.Content.ReadFromJsonAsync<Product>();
        Assert.NotNull(updated);
        Assert.Equal("更新後商品", updated.Name);
        Assert.Equal(200m, updated.Price);
        Assert.Equal(created.Id, updated.Id);
    }

    [Fact]
    public async Task UpdateProduct_ReturnsNotFound_WhenProductDoesNotExist()
    {
        var updateRequest = new UpdateProductRequest
        {
            Name = "存在しない商品",
            Description = "説明",
            Price = 100m,
            Category = "カテゴリ"
        };

        var response = await _client.PutAsJsonAsync($"/api/products/{Guid.NewGuid()}", updateRequest);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task DeleteProduct_ReturnsNoContent()
    {
        var request = new CreateProductRequest
        {
            Name = "削除テスト商品",
            Description = "削除対象",
            Price = 300m,
            Category = "カテゴリD"
        };
        var createResponse = await _client.PostAsJsonAsync("/api/products", request);
        var created = await createResponse.Content.ReadFromJsonAsync<Product>();
        Assert.NotNull(created);

        var deleteResponse = await _client.DeleteAsync($"/api/products/{created.Id}");
        Assert.Equal(HttpStatusCode.NoContent, deleteResponse.StatusCode);

        var getResponse = await _client.GetAsync($"/api/products/{created.Id}");
        Assert.Equal(HttpStatusCode.NotFound, getResponse.StatusCode);
    }

    [Fact]
    public async Task DeleteProduct_ReturnsNotFound_WhenProductDoesNotExist()
    {
        var response = await _client.DeleteAsync($"/api/products/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task GetAll_FiltersByCategory()
    {
        var requestA = new CreateProductRequest
        {
            Name = "フィルタ商品A",
            Price = 100m,
            Category = "フィルタカテゴリ"
        };
        var requestB = new CreateProductRequest
        {
            Name = "フィルタ商品B",
            Price = 200m,
            Category = "別カテゴリ"
        };
        await _client.PostAsJsonAsync("/api/products", requestA);
        await _client.PostAsJsonAsync("/api/products", requestB);

        var response = await _client.GetAsync("/api/products?category=フィルタカテゴリ");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var products = await response.Content.ReadFromJsonAsync<List<Product>>();
        Assert.NotNull(products);
        Assert.All(products, p => Assert.Equal("フィルタカテゴリ", p.Category));
    }

    [Fact]
    public async Task HealthCheck_ReturnsOk()
    {
        var healthz = await _client.GetAsync("/healthz");
        Assert.Equal(HttpStatusCode.OK, healthz.StatusCode);

        var readyz = await _client.GetAsync("/readyz");
        Assert.Equal(HttpStatusCode.OK, readyz.StatusCode);
    }
}
