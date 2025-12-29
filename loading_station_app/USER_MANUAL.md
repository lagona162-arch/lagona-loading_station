# Lagona Loading Station App - User Manual

## About This App

The **Lagona Loading Station App** is designed for loading station operators to manage daily operations including rider management, delivery tracking, wallet transactions, and merchant coordination within the Lagona ecosystem.

**System Hierarchy:** Business Hub to Loading Station to Riders to Merchants

---

## First Time Setup

### Step 1: Login
1. Open the Lagona Loading Station App
2. Enter your registered **email** and **password**
3. Tap **"Sign In"**

### Step 2: Verify LSCODE
After successful login, verify your Loading Station Code:

1. Enter your **LSCODE** (e.g., `LS031253`)
2. Tap **"Verify"**
3. Once verified, you'll access the dashboard

> **Note:** LSCODE verification is required once. Future logins will go directly to the dashboard.

---

## Dashboard Overview

The dashboard is your main control center showing:

### Key Metrics (Top Cards)
- **Station Balance:** Your current wallet balance
- **Active Deliveries:** In-progress deliveries count
- **Riders:** Total riders and pending approvals
- **Merchants:** Total merchants and onboarding status

### Quick Access Sections
1. **Pabili & Padala Board** - Tap "View all" to see all deliveries
2. **Rider Registration** - Tap "View riders" to manage riders
3. **Merchants & Priority Riders** - Tap "Assign riders" to set priorities
4. **LSCODE QR Code** - Tap the QR icon to view/share your LSCODE

### Pull to Refresh
- Pull down on the dashboard to refresh all data
- Last sync time is shown at the bottom

---

## Deliveries Tab

View and filter all delivery orders:

### Filter Options
- **Active**: Currently in-progress deliveries
- **Completed**: Finished deliveries
- **Pabili**: Purchase requests
- **Padala**: Package deliveries

### Delivery Details
Each delivery shows:
- **Merchant name**
- **Assigned rider**
- **Pickup and dropoff addresses**
- **Delivery fee**
- **Current status**

---

## Riders Tab

### Pending Riders
Riders awaiting your approval:
1. Review rider information
2. Tap **"Approve"** to activate or **"Reject"** to decline
3. Approved riders move to the active list

### Active Riders
Manage your approved riders:

**View Rider Information:**
1. Tap **"View Rider Information"** button
2. See details:
   - Contact number
   - Current wallet balance
   - Vehicle type
   - Last active location
3. Tap **"View Last Location"** to open in maps app

---

## Wallet & Top-Ups Tab

### Station Wallet Card
- **Current Balance:** Available funds in your station wallet
- **Bonus Rate:** Commission percentage set by admin (typically 10% for loading stations)
- **Business Hub:** Your connected business hub name

### Request Top-Up from Business Hub
1. Tap **"Request Top-Up"** button (bottom right, orange button)
2. Enter the amount (e.g., ₱500.00)
3. Tap **"Submit Request"**
4. Status shows: **"Waiting for Business Hub approval"**
5. Once approved by Business Hub, your balance is credited with amount + bonus

### Approve/Reject Rider Top-Up Requests
When riders request top-up from your station:

1. Find the pending request showing **"Rider to Station Wallet"**
2. Tap **"Approve"** or **"Reject"**
3. **Breakdown Modal** appears showing:
   - Requested Amount (e.g., ₱100.00)
   - Bonus Rate (e.g., 5% for riders)
   - Bonus Amount (e.g., ₱5.00)
   - **Total to Credit** (e.g., ₱105.00)
4. Tap **"Confirm Approve"** or **"Confirm Reject"**

**What Happens on Approval:**
- **Rider's balance is credited** with the total amount
- **Your station balance is deducted** by the total amount
- **Important:** Ensure you have sufficient balance before approving

### View Top-Up History
- Tap the **pending icon** (top right) to toggle:
  - **"Recent top-ups"**: All transactions
  - **"Pending Requests"**: Only pending items
- Each entry shows status: Pending, Approved, or Rejected

---

## Merchants Tab

### Merchant List
View all merchants connected to your loading station:
- **Merchant business name**
- **Number of riders handled**
- **Registration status**

### Assign Rider Priorities
Set which riders get priority for each merchant:

1. Tap on a **merchant** from the list
2. View all available riders
3. Toggle the **priority switch** for riders you want to prioritize
4. Priority riders will be assigned first to that merchant's deliveries

---

## Common Tasks

### Daily Operations

**Morning Routine:**
1. Check dashboard for pending rider approvals
2. Review active deliveries
3. Check station wallet balance
4. Approve any pending rider top-up requests

**Processing Rider Top-Up:**
1. Go to **Wallet** tab
2. Find pending rider request (shows "Rider to Station Wallet")
3. Tap **"Approve"**
4. Review breakdown in modal
5. Confirm approval
6. Verify balance updated correctly

**Requesting Funds:**
1. Go to **Wallet** tab
2. Tap **"Request Top-Up"** button
3. Enter needed amount
4. Submit and wait for Business Hub approval

**Managing Priorities:**
1. Go to **Merchants** tab
2. Select merchant
3. Toggle priority for preferred riders
4. Changes save automatically

---

## Important Notes

### Balance Management
- **Always check balance before approving rider top-ups**
- **Your station balance must cover the total amount** (requested amount plus bonus)
- **Insufficient balance will prevent approval**

### Top-Up Flow
- **Loading Station to Business Hub:** You request, Business Hub approves
- **Rider to Loading Station:** Rider requests, you approve

### Commission Rates
- **Rates are set by admin** in commission_settings table
- **Loading stations typically get 10% bonus**
- **Riders typically get 5% bonus**
- **Rates are automatically calculated** when processing requests

---

## Troubleshooting

### Login Issues
- Verify email and password
- Check internet connection
- Contact Business Hub if account locked

### LSCODE Not Verifying
- Check for typos (case-insensitive)
- Ensure LSCODE is active
- Contact support if code is correct but fails

### Balance Not Updating
- Wait a few seconds after approval
- Pull down to refresh dashboard
- Navigate away and back to Wallet tab
- Check if request was actually approved

### Can't Approve Rider Top-Up
- **Check your station balance** - must be sufficient to cover the total amount
- **Verify rider belongs to your station**
- **Ensure internet connection is stable**
- **Try refreshing the page** by navigating away and back

### Top-Up Request Not Showing
- Toggle to "Pending requests" view (top right icon)
- Pull to refresh
- Check if request was successfully submitted

---

## Security

- **Never share** your login credentials
- **Keep LSCODE private** - only share with authorized personnel
- **Log out** when using shared devices
- **Report** any suspicious activity immediately

---

## Getting Help

- Contact your **Business Hub administrator** for account issues
- Refer to Business Hub for system-wide problems
- Check app notifications for updates

---

## Navigation

**Bottom Navigation Bar:**
- **Overview (Dashboard)** - Main control center
- **Deliveries** - All delivery orders
- **Riders** - Rider management
- **Wallet** - Top-ups and balance
- **Merchants** - Merchant and priority management

**Quick Actions:**
- **Pull down anywhere on dashboard to refresh**
- **Tap section headers with "View all" to see full lists**
- **Use back button or swipe to navigate back**

---

*Lagona Loading Station App v1.0*  
*Last Updated: December 2024*
