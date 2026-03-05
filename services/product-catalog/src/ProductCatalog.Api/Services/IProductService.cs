using ProductCatalog.Api.Models;

namespace ProductCatalog.Api.Services;

public interface IProductService
{
    IEnumerable<Product> GetAll(string? category = null);
    Product? GetById(Guid id);
    Product Create(CreateProductRequest request);
    Product? Update(Guid id, UpdateProductRequest request);
    bool Delete(Guid id);
}
