import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import { Plus, Trash2, Upload, X, AlertCircle } from 'lucide-react';

interface Customer {
  id: string;
  company_name: string;
}

interface Product {
  id: string;
  product_name: string;
  product_code: string;
}

interface StockInfo {
  total_stock: number;
  reserved_stock: number;
  free_stock: number;
}

interface OrderItem {
  product_id: string;
  quantity: number;
  unit_price: number;
  discount_percent: number;
  discount_amount: number;
  tax_percent: number;
  tax_amount: number;
  line_total: number;
  item_delivery_date?: string;
  notes?: string;
}

interface SalesOrderFormProps {
  onSuccess: () => void;
  onCancel: () => void;
}

export default function SalesOrderForm({ onSuccess, onCancel }: SalesOrderFormProps) {
  const { user } = useAuth();
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [products, setProducts] = useState<Product[]>([]);
  const [stockInfo, setStockInfo] = useState<Record<string, StockInfo>>({});
  const [loading, setLoading] = useState(false);

  const [formData, setFormData] = useState({
    customer_id: '',
    customer_po_number: '',
    customer_po_date: new Date().toISOString().split('T')[0],
    so_date: new Date().toISOString().split('T')[0],
    expected_delivery_date: '',
    notes: '',
  });

  const [poFile, setPoFile] = useState<File | null>(null);
  const [items, setItems] = useState<OrderItem[]>([
    {
      product_id: '',
      quantity: 1,
      unit_price: 0,
      discount_percent: 0,
      discount_amount: 0,
      tax_percent: 0,
      tax_amount: 0,
      line_total: 0,
      item_delivery_date: '',
      notes: '',
    },
  ]);

  useEffect(() => {
    fetchCustomers();
    fetchProducts();
  }, []);

  const fetchCustomers = async () => {
    try {
      const { data, error } = await supabase
        .from('customers')
        .select('id, company_name')
        .eq('is_active', true)
        .order('company_name');

      if (error) throw error;
      setCustomers(data || []);
    } catch (error: any) {
      console.error('Error fetching customers:', error.message);
    }
  };

  const fetchProducts = async () => {
    try {
      const { data, error } = await supabase
        .from('products')
        .select('id, product_name, product_code')
        .eq('is_active', true)
        .order('product_name');

      if (error) throw error;
      setProducts(data || []);
    } catch (error: any) {
      console.error('Error fetching products:', error.message);
    }
  };

  const fetchStockInfo = async (productId: string) => {
    try {
      const { data: batches, error } = await supabase
        .from('batches')
        .select('id, current_stock')
        .eq('product_id', productId);

      if (error) throw error;

      const totalStock = batches?.reduce((sum, b) => sum + Number(b.current_stock), 0) || 0;

      const { data: reservations } = await supabase
        .from('stock_reservations')
        .select('reserved_quantity')
        .eq('product_id', productId)
        .eq('status', 'active');

      const reservedStock = reservations?.reduce((sum, r) => sum + Number(r.reserved_quantity), 0) || 0;
      const freeStock = totalStock - reservedStock;

      setStockInfo(prev => ({
        ...prev,
        [productId]: { total_stock: totalStock, reserved_stock: reservedStock, free_stock: freeStock }
      }));
    } catch (error: any) {
      console.error('Error fetching stock info:', error.message);
    }
  };

  const handleProductChange = (index: number, productId: string) => {
    const product = products.find(p => p.id === productId);
    if (!product) return;

    const newItems = [...items];
    newItems[index].product_id = productId;
    newItems[index].unit_price = 0;
    setItems(newItems);
    calculateLineTotal(index);
    fetchStockInfo(productId);
  };

  const calculateLineTotal = (index: number) => {
    const item = items[index];
    const subtotal = item.quantity * item.unit_price;
    const discountAmount = item.discount_percent > 0
      ? (subtotal * item.discount_percent) / 100
      : item.discount_amount;
    const afterDiscount = subtotal - discountAmount;
    const taxAmount = (afterDiscount * item.tax_percent) / 100;
    const lineTotal = afterDiscount + taxAmount;

    const newItems = [...items];
    newItems[index] = {
      ...item,
      discount_amount: discountAmount,
      tax_amount: taxAmount,
      line_total: lineTotal,
    };
    setItems(newItems);
  };

  const handleItemChange = (index: number, field: keyof OrderItem, value: any) => {
    const newItems = [...items];
    newItems[index] = { ...newItems[index], [field]: value };

    const item = newItems[index];
    const subtotal = item.quantity * item.unit_price;
    const discountAmount = item.discount_percent > 0
      ? (subtotal * item.discount_percent) / 100
      : item.discount_amount;
    const afterDiscount = subtotal - discountAmount;
    const taxAmount = (afterDiscount * item.tax_percent) / 100;
    const lineTotal = afterDiscount + taxAmount;

    newItems[index] = {
      ...item,
      discount_amount: discountAmount,
      tax_amount: taxAmount,
      line_total: lineTotal,
    };

    setItems(newItems);
  };

  const addItem = () => {
    setItems([
      ...items,
      {
        product_id: '',
        quantity: 1,
        unit_price: 0,
        discount_percent: 0,
        discount_amount: 0,
        tax_percent: 0,
        tax_amount: 0,
        line_total: 0,
        item_delivery_date: '',
        notes: '',
      },
    ]);
  };

  const removeItem = (index: number) => {
    if (items.length === 1) {
      alert('At least one item is required');
      return;
    }
    setItems(items.filter((_, i) => i !== index));
  };

  const uploadPoFile = async () => {
    if (!poFile) return null;

    try {
      const fileExt = poFile.name.split('.').pop();
      const fileName = `${Date.now()}_${Math.random().toString(36).substring(7)}.${fileExt}`;
      const filePath = `customer-po/${fileName}`;

      const { error: uploadError } = await supabase.storage
        .from('sales-order-documents')
        .upload(filePath, poFile);

      if (uploadError) throw uploadError;

      const { data: { publicUrl } } = supabase.storage
        .from('sales-order-documents')
        .getPublicUrl(filePath);

      return publicUrl;
    } catch (error: any) {
      console.error('Error uploading file:', error.message);
      throw error;
    }
  };

  const handleSubmit = async (e: React.FormEvent, submitForApproval: boolean = false) => {
    e.preventDefault();

    if (!formData.customer_id) {
      alert('Please select a customer');
      return;
    }

    if (!formData.customer_po_number.trim()) {
      alert('Please enter customer PO number');
      return;
    }

    if (items.length === 0 || items.some(item => !item.product_id || item.quantity <= 0)) {
      alert('Please add valid items to the order');
      return;
    }

    try {
      setLoading(true);

      let poFileUrl = null;
      if (poFile) {
        poFileUrl = await uploadPoFile();
      }

      const subtotal = items.reduce((sum, item) => sum + (item.quantity * item.unit_price - item.discount_amount), 0);
      const tax = items.reduce((sum, item) => sum + item.tax_amount, 0);
      const total = items.reduce((sum, item) => sum + item.line_total, 0);

      const { data: soData, error: soError } = await supabase
        .from('sales_orders')
        .insert({
          so_number: '',
          customer_id: formData.customer_id,
          customer_po_number: formData.customer_po_number,
          customer_po_date: formData.customer_po_date,
          customer_po_file_url: poFileUrl,
          so_date: formData.so_date,
          expected_delivery_date: formData.expected_delivery_date || null,
          notes: formData.notes || null,
          status: submitForApproval ? 'pending_approval' : 'draft',
          subtotal_amount: subtotal,
          tax_amount: tax,
          total_amount: total,
          created_by: user?.id,
        })
        .select()
        .single();

      if (soError) throw soError;

      const itemsToInsert = items.map(item => ({
        sales_order_id: soData.id,
        product_id: item.product_id,
        quantity: item.quantity,
        unit_price: item.unit_price,
        discount_percent: item.discount_percent,
        discount_amount: item.discount_amount,
        tax_percent: item.tax_percent,
        tax_amount: item.tax_amount,
        line_total: item.line_total,
        item_delivery_date: item.item_delivery_date || null,
        notes: item.notes || null,
      }));

      const { error: itemsError } = await supabase
        .from('sales_order_items')
        .insert(itemsToInsert);

      if (itemsError) throw itemsError;

      alert(`Sales order created successfully${submitForApproval ? ' and submitted for approval' : ''}!`);
      onSuccess();
    } catch (error: any) {
      console.error('Error creating sales order:', error.message);
      alert('Failed to create sales order: ' + error.message);
    } finally {
      setLoading(false);
    }
  };

  const getStockBadge = (productId: string, quantity: number) => {
    const stock = stockInfo[productId];
    if (!stock) return null;

    const hasEnough = stock.free_stock >= quantity;
    return (
      <div className={`text-xs ${hasEnough ? 'text-green-600' : 'text-red-600'}`}>
        Free Stock: {stock.free_stock} {!hasEnough && '(Insufficient!)'}
      </div>
    );
  };

  const subtotal = items.reduce((sum, item) => sum + (item.quantity * item.unit_price - item.discount_amount), 0);
  const totalTax = items.reduce((sum, item) => sum + item.tax_amount, 0);
  const grandTotal = items.reduce((sum, item) => sum + item.line_total, 0);

  return (
    <form className="space-y-6">
      <div className="grid grid-cols-2 gap-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Customer *</label>
          <select
            value={formData.customer_id}
            onChange={(e) => setFormData({ ...formData, customer_id: e.target.value })}
            className="w-full border rounded-lg px-3 py-2"
            required
          >
            <option value="">Select Customer</option>
            {customers.map(customer => (
              <option key={customer.id} value={customer.id}>
                {customer.company_name}
              </option>
            ))}
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Customer PO Number *</label>
          <input
            type="text"
            value={formData.customer_po_number}
            onChange={(e) => setFormData({ ...formData, customer_po_number: e.target.value })}
            className="w-full border rounded-lg px-3 py-2"
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Customer PO Date *</label>
          <input
            type="date"
            value={formData.customer_po_date}
            onChange={(e) => setFormData({ ...formData, customer_po_date: e.target.value })}
            className="w-full border rounded-lg px-3 py-2"
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">SO Date</label>
          <input
            type="date"
            value={formData.so_date}
            onChange={(e) => setFormData({ ...formData, so_date: e.target.value })}
            className="w-full border rounded-lg px-3 py-2"
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Expected Delivery Date</label>
          <input
            type="date"
            value={formData.expected_delivery_date}
            onChange={(e) => setFormData({ ...formData, expected_delivery_date: e.target.value })}
            className="w-full border rounded-lg px-3 py-2"
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Customer PO File (PDF/Image)</label>
          <div className="flex items-center gap-2">
            <input
              type="file"
              accept=".pdf,.jpg,.jpeg,.png"
              onChange={(e) => setPoFile(e.target.files?.[0] || null)}
              className="w-full border rounded-lg px-3 py-2"
            />
            {poFile && (
              <button
                type="button"
                onClick={() => setPoFile(null)}
                className="text-red-600 hover:text-red-800"
              >
                <X className="w-5 h-5" />
              </button>
            )}
          </div>
        </div>
      </div>

      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1">Notes</label>
        <textarea
          value={formData.notes}
          onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
          className="w-full border rounded-lg px-3 py-2"
          rows={2}
        />
      </div>

      <div>
        <div className="flex justify-between items-center mb-3">
          <label className="block text-sm font-medium text-gray-700">Order Items</label>
          <button
            type="button"
            onClick={addItem}
            className="flex items-center gap-1 text-blue-600 hover:text-blue-800 text-sm"
          >
            <Plus className="w-4 h-4" /> Add Item
          </button>
        </div>

        <div className="space-y-3 max-h-96 overflow-y-auto">
          {items.map((item, index) => (
            <div key={index} className="border rounded-lg p-3 bg-gray-50">
              <div className="grid grid-cols-6 gap-2">
                <div className="col-span-2">
                  <label className="text-xs text-gray-600">Product *</label>
                  <select
                    value={item.product_id}
                    onChange={(e) => handleProductChange(index, e.target.value)}
                    className="w-full border rounded px-2 py-1 text-sm"
                    required
                  >
                    <option value="">Select Product</option>
                    {products.map(product => (
                      <option key={product.id} value={product.id}>
                        {product.product_name}
                      </option>
                    ))}
                  </select>
                  {item.product_id && getStockBadge(item.product_id, item.quantity)}
                </div>

                <div>
                  <label className="text-xs text-gray-600">Quantity *</label>
                  <input
                    type="text"
                    value={item.quantity === 0 ? '' : item.quantity}
                    onChange={(e) => {
                      const val = e.target.value;
                      if (val === '') {
                        handleItemChange(index, 'quantity', 0);
                      } else {
                        const num = parseFloat(val);
                        if (!isNaN(num)) {
                          handleItemChange(index, 'quantity', num);
                        }
                      }
                    }}
                    onBlur={(e) => {
                      if (e.target.value === '') {
                        handleItemChange(index, 'quantity', 0);
                      }
                    }}
                    className="w-full border rounded px-2 py-1 text-sm"
                    placeholder="Enter quantity"
                    required
                  />
                </div>

                <div>
                  <label className="text-xs text-gray-600">Unit Price</label>
                  <input
                    type="text"
                    value={item.unit_price === 0 ? '' : item.unit_price}
                    onChange={(e) => {
                      const val = e.target.value;
                      if (val === '') {
                        handleItemChange(index, 'unit_price', 0);
                      } else {
                        const num = parseFloat(val);
                        if (!isNaN(num)) {
                          handleItemChange(index, 'unit_price', num);
                        }
                      }
                    }}
                    onBlur={(e) => {
                      if (e.target.value === '') {
                        handleItemChange(index, 'unit_price', 0);
                      }
                    }}
                    className="w-full border rounded px-2 py-1 text-sm"
                    placeholder="Enter price"
                  />
                </div>

                <div>
                  <label className="text-xs text-gray-600">Discount %</label>
                  <input
                    type="text"
                    value={item.discount_percent === 0 ? '' : item.discount_percent}
                    onChange={(e) => {
                      const val = e.target.value;
                      if (val === '') {
                        handleItemChange(index, 'discount_percent', 0);
                      } else {
                        const num = parseFloat(val);
                        if (!isNaN(num) && num >= 0 && num <= 100) {
                          handleItemChange(index, 'discount_percent', num);
                        }
                      }
                    }}
                    onBlur={(e) => {
                      if (e.target.value === '') {
                        handleItemChange(index, 'discount_percent', 0);
                      }
                    }}
                    className="w-full border rounded px-2 py-1 text-sm"
                    placeholder="0"
                  />
                </div>

                <div>
                  <label className="text-xs text-gray-600">Tax %</label>
                  <input
                    type="text"
                    value={item.tax_percent === 0 ? '' : item.tax_percent}
                    onChange={(e) => {
                      const val = e.target.value;
                      if (val === '') {
                        handleItemChange(index, 'tax_percent', 0);
                      } else {
                        const num = parseFloat(val);
                        if (!isNaN(num) && num >= 0 && num <= 100) {
                          handleItemChange(index, 'tax_percent', num);
                        }
                      }
                    }}
                    onBlur={(e) => {
                      if (e.target.value === '') {
                        handleItemChange(index, 'tax_percent', 0);
                      }
                    }}
                    className="w-full border rounded px-2 py-1 text-sm"
                    placeholder="0"
                  />
                </div>
              </div>

              <div className="grid grid-cols-6 gap-2 mt-2">
                <div className="col-span-2">
                  <label className="text-xs text-gray-600">Item Delivery Date</label>
                  <input
                    type="date"
                    value={item.item_delivery_date}
                    onChange={(e) => handleItemChange(index, 'item_delivery_date', e.target.value)}
                    className="w-full border rounded px-2 py-1 text-sm"
                  />
                </div>

                <div className="col-span-3">
                  <label className="text-xs text-gray-600">Notes</label>
                  <input
                    type="text"
                    value={item.notes}
                    onChange={(e) => handleItemChange(index, 'notes', e.target.value)}
                    className="w-full border rounded px-2 py-1 text-sm"
                  />
                </div>

                <div className="flex items-end justify-between">
                  <div>
                    <label className="text-xs text-gray-600">Line Total</label>
                    <div className="text-sm font-medium">${item.line_total.toFixed(2)}</div>
                  </div>
                  <button
                    type="button"
                    onClick={() => removeItem(index)}
                    className="text-red-600 hover:text-red-800"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="bg-gray-50 p-4 rounded-lg">
        <div className="space-y-2">
          <div className="flex justify-between text-sm">
            <span>Subtotal:</span>
            <span className="font-medium">${subtotal.toFixed(2)}</span>
          </div>
          <div className="flex justify-between text-sm">
            <span>Tax:</span>
            <span className="font-medium">${totalTax.toFixed(2)}</span>
          </div>
          <div className="flex justify-between text-lg font-bold border-t pt-2">
            <span>Grand Total:</span>
            <span>${grandTotal.toFixed(2)}</span>
          </div>
        </div>
      </div>

      <div className="flex justify-end gap-3">
        <button
          type="button"
          onClick={onCancel}
          className="px-4 py-2 border rounded-lg hover:bg-gray-50"
          disabled={loading}
        >
          Cancel
        </button>
        <button
          type="button"
          onClick={(e) => handleSubmit(e, false)}
          className="px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700"
          disabled={loading}
        >
          {loading ? 'Saving...' : 'Save as Draft'}
        </button>
        <button
          type="button"
          onClick={(e) => handleSubmit(e, true)}
          className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          disabled={loading}
        >
          {loading ? 'Submitting...' : 'Submit for Approval'}
        </button>
      </div>
    </form>
  );
}
