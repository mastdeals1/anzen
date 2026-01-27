# WhatsApp Integration Guide (Free - No API Costs)

## Overview

This guide explains how to integrate WhatsApp into your CRM without using the expensive WhatsApp Business API.

**Cost Comparison:**
- WhatsApp Business API: $0.005-0.009 per message (~$500-900 for 100,000 messages)
- Our Solution (Click-to-Chat): **FREE** (unlimited messages)

---

## How It Works

### The "Click-to-Chat" Approach

Instead of sending messages programmatically, we generate special WhatsApp links that:
1. Open WhatsApp Web/App automatically
2. Pre-fill the message for the user
3. User just clicks "Send" (1-click)

**Benefits:**
- ✅ Completely free
- ✅ Official WhatsApp feature (no ToS violation)
- ✅ Works on desktop and mobile
- ✅ No setup or verification required
- ✅ User can edit message before sending
- ✅ Works with personal or business WhatsApp

---

## Implementation Code

### 1. Utility Function

Create `src/utils/whatsapp.ts`:

```typescript
export const whatsappUtils = {
  /**
   * Generate WhatsApp click-to-chat URL
   * @param phone - Phone number (can include +, spaces, dashes)
   * @param message - Pre-filled message
   * @returns WhatsApp URL
   */
  generateLink: (phone: string, message: string): string => {
    // Clean phone number (remove spaces, dashes, etc.)
    const cleanPhone = phone.replace(/[^0-9]/g, '');

    // Convert to international format
    // If starts with 0, replace with 62 (Indonesia)
    const intlPhone = cleanPhone.startsWith('0')
      ? '62' + cleanPhone.slice(1)
      : cleanPhone;

    // URL encode the message
    const encodedMessage = encodeURIComponent(message);

    return `https://wa.me/${intlPhone}?text=${encodedMessage}`;
  },

  /**
   * Format phone number for display
   */
  formatPhone: (phone: string): string => {
    const clean = phone.replace(/[^0-9]/g, '');
    if (clean.startsWith('62')) {
      return `+62 ${clean.slice(2, 5)}-${clean.slice(5, 9)}-${clean.slice(9)}`;
    }
    return phone;
  },

  /**
   * Validate Indonesian phone number
   */
  isValidPhone: (phone: string): boolean => {
    const clean = phone.replace(/[^0-9]/g, '');
    // Indonesian numbers: 08xx or 62xxx (10-13 digits)
    return /^(0|62)[0-9]{9,12}$/.test(clean);
  },

  /**
   * Get message template
   */
  getTemplate: (type: string, variables: any): string => {
    const templates: Record<string, (v: any) => string> = {
      inquiry_followup: (v) =>
        `Hi ${v.customerName},\n\nFollowing up on inquiry ${v.inquiryNo} dated ${v.date}.\n\n${v.notes || 'Please let us know if you have any questions.'}\n\nBest regards,\n${v.companyName}`,

      quote_sent: (v) =>
        `Hi ${v.customerName},\n\nWe've sent you a quotation for inquiry ${v.inquiryNo}.\n\nQuote No: ${v.quoteNo}\nValid until: ${v.validUntil}\n\nPlease review and let us know if you have any questions.\n\nBest regards,\n${v.companyName}`,

      order_confirmation: (v) =>
        `Hi ${v.customerName},\n\nYour order ${v.soNumber} has been confirmed!\n\nDelivery Challan: ${v.dcNumber}\nExpected delivery: ${v.deliveryDate}\n\nThank you for your business.\n\nBest regards,\n${v.companyName}`,

      payment_reminder: (v) =>
        `Hi ${v.customerName},\n\nFriendly reminder about invoice ${v.invoiceNo}.\n\nAmount due: Rp ${v.amount.toLocaleString('id-ID')}\nDue date: ${v.dueDate}\n\nPlease arrange payment at your earliest convenience.\n\nBest regards,\n${v.companyName}`,

      delivery_notification: (v) =>
        `Hi ${v.customerName},\n\nYour order ${v.dcNumber} is out for delivery today!\n\nDriver: ${v.driverName}\nVehicle: ${v.vehicleNumber}\nETA: ${v.eta}\n\nBest regards,\n${v.companyName}`,

      meeting_reminder: (v) =>
        `Hi ${v.customerName},\n\nReminder about our meeting:\n\nDate: ${v.meetingDate}\nTime: ${v.meetingTime}\nLocation: ${v.location || 'To be confirmed'}\n\nLooking forward to meeting you!\n\nBest regards,\n${v.companyName}`,
    };

    return templates[type] ? templates[type](variables) : '';
  },
};
```

---

### 2. Add WhatsApp Button Component

Create `src/components/WhatsAppButton.tsx`:

```typescript
import { MessageCircle } from 'lucide-react';
import { whatsappUtils } from '../utils/whatsapp';

interface WhatsAppButtonProps {
  phone: string;
  message: string;
  onSend?: () => void;
  variant?: 'primary' | 'secondary' | 'icon';
  label?: string;
}

export function WhatsAppButton({
  phone,
  message,
  onSend,
  variant = 'primary',
  label = 'Send WhatsApp'
}: WhatsAppButtonProps) {
  const handleClick = () => {
    if (!whatsappUtils.isValidPhone(phone)) {
      alert('Invalid phone number');
      return;
    }

    const url = whatsappUtils.generateLink(phone, message);
    window.open(url, '_blank');

    if (onSend) {
      onSend();
    }
  };

  if (variant === 'icon') {
    return (
      <button
        onClick={handleClick}
        className="p-2 text-green-600 hover:bg-green-50 rounded-lg transition"
        title="Send via WhatsApp"
      >
        <MessageCircle className="w-5 h-5" />
      </button>
    );
  }

  if (variant === 'secondary') {
    return (
      <button
        onClick={handleClick}
        className="flex items-center gap-2 px-4 py-2 border border-green-600 text-green-600 hover:bg-green-50 rounded-lg transition"
      >
        <MessageCircle className="w-4 h-4" />
        {label}
      </button>
    );
  }

  return (
    <button
      onClick={handleClick}
      className="flex items-center gap-2 px-4 py-2 bg-green-500 hover:bg-green-600 text-white rounded-lg transition shadow-sm"
    >
      <MessageCircle className="w-4 h-4" />
      {label}
    </button>
  );
}
```

---

### 3. Usage Examples

#### A. In Customer Detail Page

```typescript
import { WhatsAppButton } from '../components/WhatsAppButton';
import { whatsappUtils } from '../utils/whatsapp';

// In customer detail component
const customer = {
  name: 'PT ABC Pharma',
  whatsapp_number: '081234567890',
  // ... other fields
};

<div className="flex gap-2">
  <WhatsAppButton
    phone={customer.whatsapp_number}
    message={whatsappUtils.getTemplate('inquiry_followup', {
      customerName: customer.name,
      inquiryNo: 'INQ-26-001',
      date: '15 Jan 2026',
      notes: 'Waiting for your feedback on the quote.',
      companyName: 'SA Pharma Jaya'
    })}
    onSend={() => {
      // Log activity
      logWhatsAppActivity({
        customer_id: customer.id,
        type: 'inquiry_followup',
        message: '...'
      });
    }}
  />
</div>
```

#### B. In Reminder Notification

```typescript
// When showing reminder notification
<div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
  <div className="flex items-start justify-between">
    <div>
      <h4 className="font-medium">Reminder: Follow up PT ABC</h4>
      <p className="text-sm text-gray-600 mt-1">
        Inquiry INQ-26-001 - Quote sent 3 days ago
      </p>
    </div>
    <WhatsAppButton
      phone={customer.whatsapp_number}
      message={whatsappUtils.getTemplate('inquiry_followup', {
        customerName: customer.name,
        inquiryNo: 'INQ-26-001',
        // ... other variables
      })}
      variant="icon"
    />
  </div>
</div>
```

#### C. Bulk WhatsApp Preparation

```typescript
// Prepare bulk messages for selected customers
const prepareBulkWhatsApp = (customers: Customer[], template: string) => {
  const messages = customers.map(customer => ({
    name: customer.name,
    phone: customer.whatsapp_number,
    url: whatsappUtils.generateLink(
      customer.whatsapp_number,
      whatsappUtils.getTemplate(template, {
        customerName: customer.name,
        // ... other variables
      })
    )
  }));

  // Show modal with all prepared links
  setShowBulkWhatsAppModal(true);
  setBulkMessages(messages);
};

// In modal, show list of links
{messages.map(msg => (
  <div key={msg.phone} className="flex items-center justify-between p-3 border-b">
    <div>
      <div className="font-medium">{msg.name}</div>
      <div className="text-sm text-gray-500">{msg.phone}</div>
    </div>
    <a
      href={msg.url}
      target="_blank"
      rel="noopener noreferrer"
      className="text-green-600 hover:text-green-700"
    >
      Send →
    </a>
  </div>
))}
```

---

### 4. Database Schema Updates

Add WhatsApp tracking:

```sql
-- Add WhatsApp number to contacts
ALTER TABLE customers
ADD COLUMN whatsapp_number TEXT;

ALTER TABLE crm_contacts
ADD COLUMN whatsapp_number TEXT;

-- Create WhatsApp activity log
CREATE TABLE whatsapp_activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES customers(id),
  contact_id UUID REFERENCES crm_contacts(id),
  inquiry_id UUID REFERENCES crm_inquiries(id),
  template_type TEXT,
  message_content TEXT,
  phone_number TEXT,
  sent_at TIMESTAMPTZ DEFAULT now(),
  sent_by UUID REFERENCES user_profiles(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE whatsapp_activities ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view all WhatsApp activities"
  ON whatsapp_activities FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Users can create WhatsApp activities"
  ON whatsapp_activities FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Grant access
GRANT SELECT, INSERT ON whatsapp_activities TO authenticated;
```

---

### 5. Activity Logging Function

```typescript
// src/services/whatsappActivity.ts
import { supabase } from '../lib/supabase';

export const logWhatsAppActivity = async (activity: {
  customer_id?: string;
  contact_id?: string;
  inquiry_id?: string;
  template_type: string;
  message_content: string;
  phone_number: string;
}) => {
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) return;

  const { error } = await supabase
    .from('whatsapp_activities')
    .insert([{
      ...activity,
      sent_by: user.id
    }]);

  if (error) {
    console.error('Error logging WhatsApp activity:', error);
  }
};
```

---

## UI Integration Points

### 1. Customer Card
Add WhatsApp quick action button next to phone/email

### 2. Inquiry Detail Page
Add "Send WhatsApp" for follow-ups

### 3. Reminder System
One-click WhatsApp from reminders

### 4. Sales Order Confirmation
Notify customer via WhatsApp

### 5. Payment Reminders
Send friendly payment reminders

### 6. Delivery Notifications
Alert customer when order is dispatched

---

## Best Practices

### 1. Always Pre-fill Professional Messages
```typescript
// Bad
const message = "Hi";

// Good
const message = `Hi ${customerName},\n\nFollowing up on inquiry ${inquiryNo}...\n\nBest regards,\nSA Pharma Jaya`;
```

### 2. Log Every Activity
Always call `logWhatsAppActivity()` to track communications

### 3. Validate Phone Numbers
Use `whatsappUtils.isValidPhone()` before generating links

### 4. Add Unsubscribe Option
Include: "Reply STOP to unsubscribe from messages"

### 5. Respect Business Hours
Only suggest WhatsApp during business hours (9 AM - 6 PM)

---

## Advantages Over WhatsApp Business API

| Feature | Click-to-Chat (Free) | Business API |
|---------|---------------------|--------------|
| Cost | Free | $0.005-0.009/msg |
| Setup Time | Immediate | Weeks (verification) |
| Approval Process | None | Meta approval required |
| Message Templates | Unlimited freedom | Pre-approved only |
| Sending Volume | Unlimited | Rate limits |
| User Experience | Personal touch | Automated |
| Compliance | 100% compliant | Complex rules |
| Best For | SMB, Trading | Enterprise, E-commerce |

---

## Limitations

1. **Manual Sending**: User must click send (can't fully automate)
2. **No Delivery Status**: Can't track if message was delivered/read
3. **No Incoming Messages**: Can't receive messages programmatically
4. **Mobile Required**: User needs WhatsApp installed

---

## Conclusion

For a pharma trading business with:
- 50-200 customers
- 20-50 daily messages
- Personal relationship focus
- Cost-consciousness

**Click-to-Chat is the PERFECT solution.**

It's free, easy to implement, officially supported by WhatsApp, and gives your team the flexibility to personalize messages while maintaining professional communication records.

---

## Next Steps

1. Add `whatsapp_number` field to customer form
2. Implement `WhatsAppButton` component
3. Add to 5 key screens (customer, inquiry, reminder, SO, payment)
4. Train team to use WhatsApp buttons
5. Monitor activity logs
6. Collect feedback and iterate

**Estimated Implementation Time:** 2-3 days
**Cost:** $0
**Expected Impact:** 30% faster customer communication
