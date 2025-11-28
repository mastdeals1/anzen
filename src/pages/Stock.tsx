import { useEffect, useState } from 'react';
import { Layout } from '../components/Layout';
import { DataTable } from '../components/DataTable';
import { useLanguage } from '../contexts/LanguageContext';
import { supabase } from '../lib/supabase';
import { Package, TrendingUp, AlertTriangle, Calendar } from 'lucide-react';
import { useNavigation } from '../contexts/NavigationContext';

interface StockSummary {
  product_id: string;
  product_name: string;
  product_code: string;
  unit: string;
  category: string;
  total_current_stock: number;
  reserved_quantity: number;
  available_quantity: number;
  active_batch_count: number;
  expired_batch_count: number;
  nearest_expiry_date: string | null;
}

interface DetailedBatch {
  id: string;
  batch_number: string;
  current_stock: number;
  reserved_quantity: number;
  available_quantity: number;
  expiry_date: string | null;
  import_date: string;
}

export function Stock() {
  const { t } = useLanguage();
  const { setCurrentPage } = useNavigation();
  const [stockSummary, setStockSummary] = useState<StockSummary[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedProduct, setSelectedProduct] = useState<StockSummary | null>(null);
  const [productBatches, setProductBatches] = useState<DetailedBatch[]>([]);

  useEffect(() => {
    loadStockSummary();
  }, []);

  const loadStockSummary = async () => {
    try {
      const { data, error } = await supabase
        .from('product_stock_summary')
        .select('*')
        .gt('total_current_stock', 0)
        .order('product_name');

      if (error) throw error;

      // Get reserved quantities for each product
      const productsWithReserved = await Promise.all(
        (data || []).map(async (product) => {
          const { data: reservedData } = await supabase
            .from('stock_reservations')
            .select('reserved_quantity')
            .eq('product_id', product.product_id)
            .eq('status', 'active');

          const reserved_quantity = reservedData?.reduce((sum, r) => sum + Number(r.reserved_quantity), 0) || 0;
          const available_quantity = product.total_current_stock - reserved_quantity;

          return {
            ...product,
            reserved_quantity,
            available_quantity
          };
        })
      );

      setStockSummary(productsWithReserved);
    } catch (error) {
      console.error('Error loading stock summary:', error);
    } finally {
      setLoading(false);
    }
  };

  const loadProductBatches = async (productId: string) => {
    try {
      const { data, error } = await supabase
        .from('batches')
        .select('id, batch_number, current_stock, expiry_date, import_date')
        .eq('product_id', productId)
        .eq('is_active', true)
        .gt('current_stock', 0)
        .order('expiry_date', { ascending: true, nullsFirst: false });

      if (error) throw error;

      // Get reserved quantities for each batch
      const batchesWithReserved = await Promise.all(
        (data || []).map(async (batch) => {
          const { data: reservedData } = await supabase
            .from('stock_reservations')
            .select('reserved_quantity')
            .eq('batch_id', batch.id)
            .eq('status', 'active');

          const reserved_quantity = reservedData?.reduce((sum, r) => sum + Number(r.reserved_quantity), 0) || 0;
          const available_quantity = batch.current_stock - reserved_quantity;

          return {
            ...batch,
            reserved_quantity,
            available_quantity
          };
        })
      );

      setProductBatches(batchesWithReserved);
    } catch (error) {
      console.error('Error loading product batches:', error);
    }
  };

  const handleProductClick = async (product: StockSummary) => {
    setSelectedProduct(product);
    await loadProductBatches(product.product_id);
  };

  const goToBatches = () => {
    setCurrentPage('batches');
  };

  const isExpired = (expiryDate: string | null) => {
    if (!expiryDate) return false;
    return new Date(expiryDate) < new Date();
  };

  const isNearExpiry = (expiryDate: string | null) => {
    if (!expiryDate) return false;
    const thirtyDaysFromNow = new Date();
    thirtyDaysFromNow.setDate(thirtyDaysFromNow.getDate() + 30);
    return new Date(expiryDate) <= thirtyDaysFromNow && !isExpired(expiryDate);
  };

  const getStockStatusColor = (stock: number, batchCount: number) => {
    if (stock === 0) return 'text-gray-400';
    if (stock < 500) return 'text-orange-600';
    return 'text-green-600';
  };

  const columns = [
    {
      key: 'product_name',
      label: 'Product',
      render: (item: StockSummary) => (
        <div className="py-1">
          <span className="font-medium text-gray-900">{item.product_name}</span>
          <span className="text-xs text-gray-500 ml-2 capitalize">({item.category})</span>
        </div>
      )
    },
    {
      key: 'stock',
      label: 'Total Stock',
      render: (item: StockSummary) => (
        <span className={`font-semibold ${getStockStatusColor(item.total_current_stock, item.active_batch_count)}`}>
          {item.total_current_stock.toLocaleString()} {item.unit}
        </span>
      )
    },
    {
      key: 'reserved',
      label: 'Reserved',
      render: (item: StockSummary) => (
        <span className="text-orange-600 font-medium">
          {item.reserved_quantity > 0 ? `${item.reserved_quantity.toLocaleString()} ${item.unit}` : '-'}
        </span>
      )
    },
    {
      key: 'available',
      label: 'Available',
      render: (item: StockSummary) => (
        <span className="text-green-600 font-semibold">
          {item.available_quantity.toLocaleString()} {item.unit}
        </span>
      )
    },
    {
      key: 'batches',
      label: 'Batches',
      render: (item: StockSummary) => (
        <span className="text-sm">
          <span className="text-blue-600 font-medium">{item.active_batch_count}</span>
          {item.expired_batch_count > 0 && (
            <span className="text-red-600 ml-1">({item.expired_batch_count} expired)</span>
          )}
        </span>
      )
    },
    {
      key: 'expiry',
      label: 'Nearest Expiry',
      render: (item: StockSummary) => (
        item.nearest_expiry_date ? (
          <span className={`text-sm ${
            isExpired(item.nearest_expiry_date) ? 'text-red-700 font-semibold' :
            isNearExpiry(item.nearest_expiry_date) ? 'text-orange-600 font-semibold' :
            'text-gray-700'
          }`}>
            {new Date(item.nearest_expiry_date).toLocaleDateString()}
            {isNearExpiry(item.nearest_expiry_date) && (
              <AlertTriangle className="w-3 h-3 inline ml-1" />
            )}
          </span>
        ) : (
          <span className="text-gray-400 text-sm">-</span>
        )
      )
    },
  ];

  const batchColumns = [
    {
      key: 'batch_number',
      label: 'Batch',
      render: (batch: DetailedBatch) => (
        <span className="font-mono text-sm">{batch.batch_number}</span>
      )
    },
    {
      key: 'total_stock',
      label: 'Total',
      render: (batch: DetailedBatch) => (
        <span className="font-semibold text-sm">{batch.current_stock.toLocaleString()} {selectedProduct?.unit}</span>
      )
    },
    {
      key: 'reserved',
      label: 'Reserved',
      render: (batch: DetailedBatch) => (
        <span className="text-orange-600 font-medium text-sm">
          {batch.reserved_quantity > 0 ? `${batch.reserved_quantity.toLocaleString()} ${selectedProduct?.unit}` : '-'}
        </span>
      )
    },
    {
      key: 'available',
      label: 'Available',
      render: (batch: DetailedBatch) => (
        <span className="text-green-600 font-semibold text-sm">
          {batch.available_quantity.toLocaleString()} {selectedProduct?.unit}
        </span>
      )
    },
    {
      key: 'import_date',
      label: 'Imported',
      render: (batch: DetailedBatch) => (
        <span className="text-sm text-gray-600">
          {new Date(batch.import_date).toLocaleDateString()}
        </span>
      )
    },
    {
      key: 'expiry_date',
      label: 'Expiry',
      render: (batch: DetailedBatch) => (
        <span className={`text-sm ${
          isExpired(batch.expiry_date) ? 'text-red-700 font-semibold' :
          isNearExpiry(batch.expiry_date) ? 'text-orange-600 font-semibold' :
          'text-gray-700'
        }`}>
          {batch.expiry_date ? new Date(batch.expiry_date).toLocaleDateString() : '-'}
        </span>
      )
    },
  ];

  const totalStock = stockSummary.reduce((sum, item) => sum + item.total_current_stock, 0);
  const totalProducts = stockSummary.length;
  const lowStockProducts = stockSummary.filter(item => item.total_current_stock < 500).length;
  const productsWithNearExpiry = stockSummary.filter(item =>
    item.nearest_expiry_date && isNearExpiry(item.nearest_expiry_date)
  ).length;

  return (
    <Layout>
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold text-gray-900">Stock Inventory</h1>
            <p className="text-gray-600 mt-1">Current stock levels across all products</p>
          </div>
          <button
            onClick={goToBatches}
            className="flex items-center gap-2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition"
          >
            <Package className="w-5 h-5" />
            View Batches
          </button>
        </div>

        {selectedProduct && (
          <div className="bg-blue-50 rounded-lg shadow-md p-4 border-l-4 border-blue-500">
            <div className="flex items-center justify-between mb-3">
              <h2 className="text-lg font-semibold text-gray-900">
                {selectedProduct.product_name} - Batch Details
              </h2>
              <button
                onClick={() => setSelectedProduct(null)}
                className="text-gray-500 hover:text-gray-700 text-xl font-bold"
              >
                ✕
              </button>
            </div>
            <DataTable
              columns={batchColumns}
              data={productBatches}
              loading={false}
            />
          </div>
        )}

        <div className="bg-white rounded-lg shadow-md overflow-hidden">
          <DataTable
            columns={columns}
            data={stockSummary}
            loading={loading}
            onRowClick={handleProductClick}
          />

          {!loading && stockSummary.length === 0 && (
            <div className="text-center py-12">
              <Package className="w-16 h-16 text-gray-300 mx-auto mb-4" />
              <p className="text-gray-500 text-lg">No stock available</p>
              <p className="text-gray-400 text-sm mt-2">All products are currently out of stock</p>
            </div>
          )}
        </div>

        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div className="bg-gradient-to-br from-blue-500 to-blue-600 rounded-lg shadow-lg p-6 text-white">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-blue-100 text-sm font-medium">Products In Stock</p>
                <p className="text-3xl font-bold mt-1">{totalProducts}</p>
              </div>
              <Package className="w-10 h-10 text-blue-200" />
            </div>
          </div>

          <div className="bg-gradient-to-br from-green-500 to-green-600 rounded-lg shadow-lg p-6 text-white">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-green-100 text-sm font-medium">Total Stock Units</p>
                <p className="text-3xl font-bold mt-1">{totalStock.toLocaleString()}</p>
              </div>
              <TrendingUp className="w-10 h-10 text-green-200" />
            </div>
          </div>

          <div className="bg-gradient-to-br from-orange-500 to-orange-600 rounded-lg shadow-lg p-6 text-white">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-orange-100 text-sm font-medium">Low Stock Items</p>
                <p className="text-3xl font-bold mt-1">{lowStockProducts}</p>
              </div>
              <AlertTriangle className="w-10 h-10 text-orange-200" />
            </div>
          </div>

          <div className="bg-gradient-to-br from-red-500 to-red-600 rounded-lg shadow-lg p-6 text-white">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-red-100 text-sm font-medium">Near Expiry</p>
                <p className="text-3xl font-bold mt-1">{productsWithNearExpiry}</p>
              </div>
              <Calendar className="w-10 h-10 text-red-200" />
            </div>
          </div>
        </div>
      </div>
    </Layout>
  );
}
