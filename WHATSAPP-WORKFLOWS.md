# WHATSAPP BEHAVIORAL WORKFLOWS
## Low-Tech Poultry Farm Management for Ghana

Based on 5 pain points from research document.

---

# PAIN #1: FEED WASTAGE & THEFT

## DAILY FLOW

**6:30 PM Daily Message:**
```
How many bags of feed did you use today?
Reply with just the number. Example: 2
```

**Farmer replies:** `2`

**Confirmation:**
```
✓ Recorded: 2 bags (Feb 11)
Per bird: 4.0 bags/bird - NORMAL
Bags left: About 23 bags
```

**If anomaly (20% higher than average):**
```
⚠️ ALERT: 3 bags used today - HIGH
Normal: 2 bags/day
Check for spillage or theft
Bags left: About 20 bags
```

**Delivery day (farmer initiates):**
```
Farmer: delivery
System: How many bags received?
Farmer: 50
System: ✓ 50 bags received. Total now: 73 bags
TIP: Count physical bags this weekend
```

## WEEKLY REVIEW (Sunday 8 AM)

```
📊 FEED REPORT (Feb 5-11)
Bags used: 14 bags = GH₵700
Per bird: 28 bags/bird/week
Last week: 26 bags/bird ✓ Similar

INVENTORY CHECK:
Expected: 59 bags
Go count today. Reply with actual count.
```

**If farmer reports gap:**
```
Farmer: 54
System: ⚠️ 5 BAGS MISSING = GH₵250 lost
Talk to farmhand today.
```

## NON-RESPONSE LOGIC

- After 2 hours: One reminder
- After 24 hours: "Reply 11 [number] for yesterday"
- After 3 days: "Should I keep reminding? Reply 1=yes, 2=pause, 3=stop"
- After 14 days no response: Stop automatically

## NOTEBOOK INTEGRATION

Farmer writes in notebook → Evening reminder comes → Farmer looks at notebook → Replies with number.

**Critical:** Owner must count physical bags weekly, not delegate to farmhand.

## PAYMENT JUSTIFICATION MOMENT

Week 2: System says "59 bags expected." Farmer counts, finds 54. System: "⚠️ 5 bags missing = GH₵250 lost. This is why you pay GH₵10/month."

## FAILURE RISKS

1. **False alarms** - Farmer didn't record delivery. Mitigation: Ask "Did you receive delivery this week?" before alerting.
2. **Farmer never counts physically** - System can't detect theft without physical verification.
3. **Farmhand figures out system** - Steals "normal" amounts. Mitigation: Weekly physical count is ultimate check.
4. **Cultural: Confronting farmhand difficult** - Use neutral language: "bags missing" not "theft."

---

# PAIN #2: SELLING WINDOW OPTIMIZATION

## DAILY FLOW

**NO daily input required** - This is the key feature.

**Batch start (once per cycle):**
```
System: New batch started?
Farmer: yes
System: How many chicks?
Farmer: 500
System: Target sell date? (example: 6 weeks)
Farmer: 6 weeks
System: ✓ Batch started Feb 11, 500 broilers
Target sell: March 25. I'll remind you.
```

**Price heard (2-3x/week, farmer initiates):**
```
Farmer: price 8.50
System: ✓ GH₵8.50/kg recorded (Feb 11)
This week's range: GH₵8.00-8.50 (HIGHEST)
Your birds: 14 days old (too young)
Target sell: March 25 (28 days away)
```

**5 days before target:**
```
📅 SELL DATE APPROACHING
Birds: 37 days old
Target: March 25 (5 days)
START CONTACTING BUYERS NOW
Recent prices: GH₵8.00-8.50, avg GH₵8.23
```

**Day after target:**
```
⚠️ PAST SELL DATE
Birds: 43 days old (1 day late)
Every extra day costs: GH₵200 in feed
Sell at GH₵8.00+ today, or wait 2-3 days max
Reply SOLD when you sell
```

## WEEKLY REVIEW (Sunday, only if batch active)

```
📊 BATCH UPDATE (Week 4)
Birds: 28 days old
Target sell: March 25 (11 days)
Price range this week: GH₵8.00-8.50
Next: Start contacting buyers in Week 5
```

## NON-RESPONSE LOGIC

- After 7 days past target: "Did you sell? Reply SOLD or WAITING"
- If WAITING: "What price offered?" → Advise based on recent average
- After 60 days from start: Assume batch ended, stop reminding

## NOTEBOOK INTEGRATION

Farmer writes batch start in notebook → System asks for details → Farmer provides from notebook.

Price tracking is OPTIONAL - system works even without price data.

## PAYMENT JUSTIFICATION MOMENT

Week 6: System says "Birds ready, GH₵8.50 is highest this week, every day costs GH₵200." Farmer sells at right time, saves GH₵1,000+ in wasted feed.

## FAILURE RISKS

1. **Farmer forgets to report batch start** - Monthly reminder: "Started new batch?"
2. **Farmer sells but doesn't tell system** - After 14 days: "Did you sell already?"
3. **Market crashes, system doesn't know** - System shows price context, not commands.
4. **Cultural: Buyer relationship > price** - System says "Kofi's price is GH₵0.50 lower" not "don't sell to Kofi."

---

# PAIN #3: SUPPLIER PAYMENT TRACKING

## DAILY FLOW

**Credit purchase (farmer initiates):**
```
Farmer: bought 50 bags from Kofi
System: How much owed?
Farmer: 2500
System: Due date? (example: 14 days)
Farmer: 14 days
System: ✓ PURCHASE from Kofi: GH₵2,500, due Feb 25
BALANCE OWED: GH₵2,500
Reply PAID when you pay
```

**Payment made:**
```
Farmer: paid Kofi 1000
System: ✓ PAYMENT: GH₵1,000 (Feb 15)
BALANCE: GH₵1,500 (was 2,500, paid 1,000)
Remaining due: Feb 25 (10 days)
```

## WEEKLY REVIEW (Sunday 9 AM)

```
💰 PAYMENT REMINDER
DUE THIS WEEK:
- Kofi: GH₵1,500 due Feb 25 (7 days)

TOTAL OWED:
- Kofi: GH₵1,500
- Ama: GH₵800
- Total: GH₵2,300

Plan cash now. Don't wait.
```

**If overdue:**
```
⚠️ OVERDUE: Kofi GH₵1,500 (3 days late)
Credit at risk. Pay ASAP.
```

## NON-RESPONSE LOGIC

- After 3 days past due: "Did you pay Kofi? Reply PAID or NOT YET"
- Weekly: "Did you make payments you forgot to record?"
- If no transactions 90 days: Stop reminding

## NOTEBOOK INTEGRATION

Farmer writes transaction in notebook → Later reports to WhatsApp → System does the math.

**Critical risk:** Spouse pays via MoMo, farmer doesn't know. Weekly reminder: "Did spouse make payments?"

## PAYMENT JUSTIFICATION MOMENT

Dispute: Kofi says "You owe GH₵3,000." Farmer shows WhatsApp: "I paid GH₵1,000 on Feb 15, balance is GH₵1,500." Avoids GH₵1,000 double-payment.

## FAILURE RISKS

1. **Farmer forgets to record payments** - Weekly: "Did you pay anyone this week?"
2. **Supplier doesn't accept farmer's records** - System gives evidence, can't force acceptance.
3. **Pre-existing disputed balance** - System asks: "Do you owe Kofi anything from before? Set starting balance."
4. **Cultural: Informal credit relationships** - Use neutral language: "balance owed" not "debt."

---

# PAIN #4: LABOR COST TRACKING

## DAILY FLOW

**7 PM attendance check:**
```
Did Kwame work today?
Reply YES or NO
```

```
Farmer: yes
System: ✓ Kwame worked (Feb 11)
Days this month: 8 days
Wages earned: GH₵240 (8 × GH₵30)
Wages owed: GH₵240 (unpaid)
```

**Payment:**
```
Farmer: paid Kwame 240
System: ✓ PAYMENT: GH₵240 (Feb 15)
Balance: GH₵0 - Fully paid
```

## WEEKLY REVIEW (Sunday 10 AM)

```
👷 WORKER WAGES (Feb 12-18)
KWAME: 6 days, GH₵180 owed
AMMA: 5 days, GH₵150 owed
TOTAL LABOR: GH₵330
```

**Month-end:**
```
📅 FEBRUARY WAGES
KWAME: 24 days worked (4 absent)
Earned: GH₵720
Paid: GH₵500
BALANCE: GH₵220 - PAY NOW
```

## NON-RESPONSE LOGIC

- After 2 hours: One reminder
- After 3 days: "Should I keep reminding?"
- After 7 days past payment date: "Did you pay Kwame?"

## NOTEBOOK INTEGRATION

Farmer writes attendance in notebook → Evening reminder → Farmer replies from notebook.

**Transparency option:** Farmer can show WhatsApp to worker to verify days worked.

## PAYMENT JUSTIFICATION MOMENT

Month-end: Worker claims GH₵900. Farmer shows: "24 days worked, 6 absent (Feb 3,5,12,18,22,25), wages = GH₵720." Avoids GH₵180 overpayment.

## FAILURE RISKS

1. **Farmer stops recording after 2 weeks** - Weekly: "You recorded 12/14 days. Keep going!"
2. **Worker disputes attendance** - System shows specific absent dates for verification.
3. **Family member as worker** - Formal tracking feels awkward. System is optional for family.
4. **Cultural: Long-term worker feels mistrusted** - Explain: "Protects both of us from memory mistakes."

---

# PAIN #5: MORTALITY PATTERN DETECTION

## DAILY FLOW

**8 AM mortality check:**
```
How many birds died yesterday?
Reply with number (or 0)
```

```
Farmer: 2
System: ✓ 2 deaths (Feb 11)
Batch A (28 days): 15 total deaths (3%)
This is NORMAL. Keep monitoring.
```

**If high mortality (>5% before day 21):**
```
⚠️ 5 deaths (Feb 11)
Batch A (14 days): 30 deaths (6%)
ALERT: HIGH for this age
Normal: 2-3%, yours: 6%
Consider calling vet
```

## WEEKLY REVIEW (Sunday, if batch active)

```
📊 BATCH HEALTH (Week 4)
Batch A (28 days): 3 deaths this week
Total: 15 deaths (3%) - NORMAL
Supplier: Akosua Hatchery
Keep recording daily
```

**Batch end summary:**
```
📊 BATCH A COMPLETE
Started: Feb 11 (500 birds)
Sold: March 25 (42 days)
Deaths: 35 (7%)

COMPARISON:
- Batch A (Akosua): 7% ← THIS
- Last (Kofi): 12%
- 2 ago (Akosua): 8%

INSIGHT: Akosua better than Kofi
SAVED: GH₵500 by using Akosua
Use Akosua next batch
```

## NON-RESPONSE LOGIC

- After 2 hours: One reminder
- After 3 days: "Should I keep reminding?"
- After 60 days: "Did you sell birds?"

## NOTEBOOK INTEGRATION

Farmhand collects dead birds → Tells farmer → Farmer writes in notebook → Morning reminder → Farmer replies from notebook.

**Critical:** Farmer records, not farmhand (data integrity).

## PAYMENT JUSTIFICATION MOMENT

After 3-4 batches: System shows "Akosua: 7% avg, Kofi: 12% avg. Switch to Akosua saves GH₵4,000/batch." Farmer switches supplier, saves GH₵24,000/year.

## FAILURE RISKS

1. **Delayed value (5-6 months)** - Needs 4-6 batches for patterns. Early batches show: "You've recorded 2 batches. Keep going for insights."
2. **Farmer forgets batch start** - Monthly: "Started new batch recently?"
3. **Incomplete data (missed days)** - Acceptable: Pattern detection tolerates gaps if batch totals are roughly accurate.
4. **Cultural: Farmhand reports wrong number** - Farmer should see dead birds weekly to cross-check.

---

# CROSS-WORKFLOW OBSERVATIONS

## Daily Time Burden
- Pain #1 (Feed): 45 seconds
- Pain #2 (Selling): 0 seconds most days
- Pain #3 (Payments): 30 seconds on transaction days
- Pain #4 (Labor): 30 seconds
- Pain #5 (Mortality): 20 seconds

**Total: Under 3 minutes/day maximum**

## Value Timeline
- Pains #1, #3, #4: Value visible within days/weeks
- Pain #2: Value visible within 1-2 batches (6-14 weeks)
- Pain #5: Value visible after 4-6 batches (5-8 months)

**Strategy:** Early wins from #1, #3, #4 motivate continued use for delayed payoff of #5.

## Payment Justification
**GH₵10/month subscription justified by:**
- One theft detection (GH₵250) = 25 months paid
- One overpayment avoided (GH₵180) = 18 months paid
- One supplier switch (GH₵4,000/batch) = 400 months paid

## Universal Failure Risks
1. **Behavior consistency** - Farmer must reply daily. This is the primary risk, not data complexity.
2. **Offline periods** - SMS fallback or batch entry: "Reply with last 3 days: 2,2,3"
3. **Literacy barriers** - Keep messages simple, use numbers not percentages.
4. **Trust in technology** - Weekly summaries show ALL entries so farmer can verify against notebook.

---

**END OF WORKFLOWS**
