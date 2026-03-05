using System.Collections.Concurrent;
using ProductCatalog.Api.Models;

namespace ProductCatalog.Api.Services;

public class ProductService : IProductService
{
    private readonly ConcurrentDictionary<Guid, Product> _products = new();

    public IEnumerable<Product> GetAll(string? category = null)
    {
        var products = _products.Values.AsEnumerable();

        if (!string.IsNullOrWhiteSpace(category))
        {
            products = products.Where(p =>
                p.Category.Equals(category, StringComparison.OrdinalIgnoreCase));
        }

        return products.OrderBy(p => p.Name);
    }

    public Product? GetById(Guid id)
    {
        return _products.GetValueOrDefault(id);
    }

    public Product Create(CreateProductRequest request)
    {
        var product = new Product
        {
            Id = Guid.NewGuid(),
            Name = request.Name,
            Description = request.Description,
            Price = request.Price,
            Category = request.Category,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _products[product.Id] = product;
        return product;
    }

    public Product? Update(Guid id, UpdateProductRequest request)
    {
        if (!_products.TryGetValue(id, out var existing))
            return null;

        var updated = new Product
        {
            Id = existing.Id,
            Name = request.Name,
            Description = request.Description,
            Price = request.Price,
            Category = request.Category,
            CreatedAt = existing.CreatedAt,
            UpdatedAt = DateTime.UtcNow
        };

        _products[id] = updated;
        return updated;
    }

    public bool Delete(Guid id)
    {
        return _products.TryRemove(id, out _);
    }
}
