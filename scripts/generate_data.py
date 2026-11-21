"""
Generates realistic, reproducible seed data for the Northbrook Outfitters
retail database and writes it to data/02_seed_data.sql.

Built-in patterns the analysis can uncover:
  * steady growth over 2024-2025 with a strong November/December peak
  * mobile app share of orders rising over time
  * referral customers repeat far more often than paid-social customers
  * Footwear has a much higher return rate (sizing issues)
  * the FLASH30 promo lifts volume but erodes margin and drives returns
  * a few products that never sold and customers who never ordered
  * a handful of duplicate customers (same email, different letter case)
  * 2025 list-price increases on ~40% of products (product_price_history)

Run:  python3 scripts/generate_data.py
"""
import math
import random
from datetime import date, timedelta
from pathlib import Path

random.seed(42)
OUT = Path(__file__).resolve().parent.parent / "data" / "02_seed_data.sql"

START, END = date(2024, 1, 1), date(2025, 12, 31)

FIRST = ["James","Mary","Robert","Patricia","John","Jennifer","Michael","Linda","David","Elizabeth",
         "William","Barbara","Richard","Susan","Joseph","Jessica","Thomas","Sarah","Charles","Karen",
         "Daniel","Lisa","Matthew","Nancy","Anthony","Betty","Mark","Sandra","Donald","Ashley",
         "Steven","Kimberly","Andrew","Emily","Joshua","Donna","Kevin","Michelle","Brian","Carol",
         "Luis","Maria","Carlos","Sofia","Wei","Mei","Arjun","Priya","Omar","Aisha","Kwame","Amara",
         "Diego","Valentina","Hiroshi","Yuki","Mateo","Camila","Ethan","Olivia","Noah","Ava"]
LAST = ["Smith","Johnson","Williams","Brown","Jones","Garcia","Miller","Davis","Rodriguez","Martinez",
        "Hernandez","Lopez","Gonzalez","Wilson","Anderson","Thomas","Taylor","Moore","Jackson","Martin",
        "Lee","Perez","Thompson","White","Harris","Sanchez","Clark","Ramirez","Lewis","Robinson",
        "Walker","Young","Allen","King","Wright","Scott","Torres","Nguyen","Hill","Flores",
        "Green","Adams","Nelson","Baker","Hall","Rivera","Campbell","Mitchell","Carter","Roberts",
        "Patel","Kim","Chen","Okafor","Mensah","Tanaka","Silva","Ali","Khan","Novak"]
CITIES = [("Chicago","IL"),("Naperville","IL"),("Austin","TX"),("Dallas","TX"),("Houston","TX"),
          ("Denver","CO"),("Boulder","CO"),("Seattle","WA"),("Portland","OR"),("San Diego","CA"),
          ("Los Angeles","CA"),("Sacramento","CA"),("Phoenix","AZ"),("Minneapolis","MN"),
          ("Madison","WI"),("Atlanta","GA"),("Nashville","TN"),("Raleigh","NC"),("Boston","MA"),
          ("New York","NY"),("Philadelphia","PA"),("Columbus","OH"),("Salt Lake City","UT"),
          ("Kansas City","MO"),("Miami","FL"),("Tampa","FL"),("Detroit","MI"),("Omaha","NE")]
CITY_WEIGHTS = [8,3,6,5,5,6,3,6,5,4,6,2,4,4,2,5,3,3,5,7,4,3,3,2,3,2,3,1]
DOMAINS = ["gmail.com","yahoo.com","outlook.com","icloud.com","proton.me"]

# channel: (share of customers, base monthly order rate, monthly retention decay)
CHANNELS = {
    "organic_search": (0.32, 0.30, 0.94),
    "paid_social":    (0.24, 0.26, 0.86),
    "email":          (0.16, 0.34, 0.95),
    "referral":       (0.14, 0.42, 0.97),
    "affiliate":      (0.14, 0.24, 0.90),
}

CATEGORIES = ["Camping Gear","Hiking Apparel","Footwear","Kitchen & Dining","Home Decor","Fitness"]
# category: [(product name, price, cost ratio)]
PRODUCTS = {
    "Camping Gear": [("Trailhead 2-Person Tent",189.00,.52),("Summit 4-Season Tent",349.00,.55),
        ("Ember Camp Stove",64.00,.48),("Nightfall Sleeping Bag 20F",129.00,.50),("Basecamp Lantern",34.00,.40),
        ("Ridge Trekking Poles",79.00,.42),("Canyon Water Filter",44.00,.38),("Pack-Lite Hammock",59.00,.36),
        ("Glacier Cooler 45qt",219.00,.58),("Firefly Headlamp",29.00,.35)],
    "Hiking Apparel": [("Alpine Rain Shell",159.00,.45),("Merino Base Layer Top",74.00,.40),
        ("Switchback Hiking Pants",69.00,.38),("Cloudpeak Down Jacket",229.00,.50),("Trail Fleece Pullover",59.00,.36),
        ("Wool Hiking Socks 3-Pack",24.00,.30),("Sun Hat Wide Brim",32.00,.30),("Quick-Dry Trail Tee",28.00,.32),
        ("Insulated Gloves",39.00,.35),("Packable Wind Vest",54.00,.38)],
    "Footwear": [("Ridgeline Hiking Boot",169.00,.50),("Trailrunner Pro Shoe",139.00,.48),
        ("Camp Slide Sandal",39.00,.35),("Waterproof Mid Boot",149.00,.50),("Winter Snow Boot",179.00,.52),
        ("Approach Shoe",129.00,.48),("Recovery Slip-On",59.00,.38),("Kids Trail Sneaker",54.00,.40),
        ("Gaiter Set",29.00,.33),("Insole Comfort Pack",19.00,.28)],
    "Kitchen & Dining": [("Cast Iron Skillet 12in",49.00,.40),("Enamel Dutch Oven",119.00,.46),
        ("Pour-Over Coffee Set",42.00,.36),("Insulated Travel Mug",26.00,.30),("Bamboo Cutting Board",34.00,.32),
        ("Stoneware Dinner Set",89.00,.44),("Chef Knife 8in",79.00,.40),("Glass Storage Set",38.00,.35),
        ("French Press 34oz",36.00,.34),("Linen Napkin Set",22.00,.30)],
    "Home Decor": [("Wool Throw Blanket",89.00,.42),("Cedar Scented Candle",24.00,.25),
        ("Woven Storage Basket",39.00,.34),("Ceramic Planter Set",46.00,.36),("Pendant Lamp",139.00,.48),
        ("Mountain Print Framed",79.00,.33),("Jute Area Rug 5x8",159.00,.50),("Linen Pillow Cover",29.00,.30),
        ("Wall Mirror Round",99.00,.45),("Reclaimed Wood Shelf",69.00,.42)],
    "Fitness": [("Cork Yoga Mat",64.00,.40),("Adjustable Dumbbell Set",249.00,.60),
        ("Resistance Band Kit",29.00,.30),("Foam Roller",32.00,.32),("Jump Rope Speed",18.00,.28),
        ("Kettlebell 35lb",69.00,.50),("Pull-Up Bar",39.00,.38),("Hydration Pack 2L",49.00,.38),
        ("Fitness Tracker Band",99.00,.52),("Balance Ball",27.00,.32)],
}
CATEGORY_WEIGHT = {"Camping Gear":1.2,"Hiking Apparel":1.3,"Footwear":1.0,"Kitchen & Dining":1.0,
                   "Home Decor":0.8,"Fitness":0.9}

RETURN_REASONS = {"Footwear": ["Wrong size","Wrong size","Wrong size","Uncomfortable fit","Changed mind"],
                  "_default": ["Changed mind","Damaged in shipping","Not as described","Arrived late","Defective"]}


def sql(v):
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "TRUE" if v else "FALSE"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, date):
        return f"'{v.isoformat()}'"
    return "'" + str(v).replace("'", "''") + "'"


def insert(f, table, cols, rows, batch=500):
    for i in range(0, len(rows), batch):
        chunk = rows[i:i + batch]
        f.write(f"INSERT INTO {table} ({', '.join(cols)}) VALUES\n")
        f.write(",\n".join("(" + ", ".join(sql(v) for v in r) + ")" for r in chunk))
        f.write(";\n\n")


def seasonality(d):
    m = d.month
    s = {1: .85, 2: .80, 3: .90, 4: .95, 5: 1.0, 6: 1.05, 7: 1.10, 8: 1.0, 9: .95, 10: 1.0, 11: 1.55, 12: 1.75}[m]
    if m == 11 and 24 <= d.day <= 30:   # Black Friday / Cyber Monday week
        s *= 1.8
    return s


# ---------------------------------------------------------------- employees
employees = [
    (1, "Grace", "Holloway", "CEO", "Executive", None, date(2019, 3, 1)),
    (2, "Marcus", "Bell", "VP Operations", "Operations", 1, date(2019, 8, 12)),
    (3, "Elena", "Ruiz", "VP Marketing", "Marketing", 1, date(2020, 1, 6)),
    (4, "Samuel", "Osei", "Customer Service Manager", "Customer Service", 2, date(2020, 5, 18)),
    (5, "Hannah", "Price", "Warehouse Manager", "Operations", 2, date(2021, 2, 1)),
    (6, "Leo", "Chang", "Growth Marketing Lead", "Marketing", 3, date(2021, 9, 13)),
    (7, "Tara", "Quinn", "Customer Service Rep", "Customer Service", 4, date(2022, 4, 4)),
    (8, "Victor", "Mendes", "Customer Service Rep", "Customer Service", 4, date(2023, 1, 9)),
    (9, "Nadia", "Farah", "Customer Service Rep", "Customer Service", 4, date(2024, 6, 3)),
    (10, "Owen", "Becker", "Fulfillment Associate", "Operations", 5, date(2022, 10, 17)),
    (11, "Iris", "Lund", "Fulfillment Associate", "Operations", 5, date(2024, 3, 11)),
    (12, "Ravi", "Shah", "Marketing Analyst", "Marketing", 6, date(2023, 7, 24)),
]
cs_reps = [7, 8, 9]

# ---------------------------------------------------------------- categories & products
categories = [(i + 1, c) for i, c in enumerate(CATEGORIES)]
cat_id = {c: i for i, c in categories}
products, pid = [], 1
product_meta = {}  # pid -> (category, price, popularity)
for cat in CATEGORIES:
    for name, price, cost_ratio in PRODUCTS[cat]:
        launch = START - timedelta(days=random.randint(30, 700))
        if random.random() < 0.12:
            launch = START + timedelta(days=random.randint(60, 600))
        products.append((pid, name, cat_id[cat], price, round(price * cost_ratio, 2), launch, True))
        popularity = random.uniform(0.4, 1.6) * CATEGORY_WEIGHT[cat] * (1.4 if price < 60 else 1.0)
        product_meta[pid] = (cat, price, popularity, launch)
        pid += 1
# three late launches / discontinued items that never sell
for name, cat, price in [("Ultralight Bivy Sack", "Camping Gear", 199.00),
                         ("Heated Base Layer", "Hiking Apparel", 189.00),
                         ("Smart Water Bottle", "Fitness", 59.00)]:
    products.append((pid, name, cat_id[cat], price, round(price * .55, 2), date(2025, 12, 28), random.random() < .5))
    pid += 1
# list-price increases during 2025 for ~40% of products (feeds product_price_history)
price_change = {}
for i, prod in enumerate(products):
    p_id, launch = prod[0], prod[5]
    if p_id in product_meta and random.random() < 0.40:
        when = max(date(2025, 1, 1) + timedelta(days=random.randint(0, 300)), launch + timedelta(days=60))
        new_price = round(prod[3] * random.uniform(1.05, 1.12)) - 0.01
        price_change[p_id] = (when, new_price)
        p = list(prod); p[3] = new_price; p[4] = round(prod[4] * 1.04, 2); products[i] = tuple(p)
price_history = []
for prod in products:
    p_id, launch = prod[0], prod[5]
    if p_id in price_change:
        when, new_price = price_change[p_id]
        old = product_meta[p_id][1]
        price_history.append((p_id, old, launch, when - timedelta(days=1)))
        price_history.append((p_id, new_price, when, None))
    else:
        price_history.append((p_id, prod[3], launch, None))


def price_on(p_id, d):
    if p_id in price_change and d >= price_change[p_id][0]:
        return price_change[p_id][1]
    return product_meta[p_id][1]


# mark a few older products discontinued
for i in random.sample(range(len(products) - 3), 4):
    p = list(products[i]); p[6] = False; products[i] = tuple(p)

# ---------------------------------------------------------------- customers
customers, cust_meta = [], {}
emails = set()
ch_names = list(CHANNELS)
ch_weights = [CHANNELS[c][0] for c in ch_names]
span = (date(2025, 11, 30) - date(2023, 7, 1)).days
for cid in range(1, 1501):
    fn, ln = random.choice(FIRST), random.choice(LAST)
    while True:
        email = f"{fn.lower()}.{ln.lower()}{random.randint(1, 999)}@{random.choice(DOMAINS)}"
        if email not in emails:
            emails.add(email); break
    # signups accelerate over time (sqrt skews toward later dates)
    signup = date(2023, 7, 1) + timedelta(days=int(span * random.random() ** 0.8))
    city, state = random.choices(CITIES, CITY_WEIGHTS)[0]
    if random.random() < 0.04:
        city, state = None, None
    ch = random.choices(ch_names, ch_weights)[0]
    customers.append([cid, fn, ln, email, city, state, signup, ch])
    cust_meta[cid] = (signup, ch)

# duplicates: same person signed up twice with different email casing
for k in range(6):
    src = customers[random.randint(0, 999)]
    cid = len(customers) + 1
    dup_email = src[3].split("@")[0].title() + "@" + src[3].split("@")[1]
    customers.append([cid, src[1], src[2], dup_email, src[4], src[5],
                      src[6] + timedelta(days=random.randint(20, 200)), src[7]])
    cust_meta[cid] = (customers[-1][6], src[7])

# ---------------------------------------------------------------- orders
orders, items, returns_ = [], [], []
oid = iid = rid = 1
active_pids = [p for p in product_meta]


def pick_products(d, n):
    avail = [p for p in active_pids if product_meta[p][3] <= d]
    w = [product_meta[p][2] for p in avail]
    return random.sample(random.choices(avail, w, k=n * 3), k=min(n, len(set(avail))))


for cid, (signup, ch) in cust_meta.items():
    _, base_rate, decay = CHANNELS[ch]
    if random.random() < 0.11:          # never ordered
        continue
    first = True
    d = max(signup, START)
    # first purchase usually soon after signup (if signup inside window)
    if signup >= START:
        d = signup + timedelta(days=int(random.expovariate(1 / 6)))
    loyalty = random.lognormvariate(0, 0.5)
    while d <= END:
        months_since = (d - signup).days / 30.4
        trend = 1 + 0.008 * ((d - START).days / 30.4)
        rate = base_rate * loyalty * seasonality(d) * trend * (decay ** months_since) / 30.4
        if first and signup >= START:
            place = True
        else:
            place = random.random() < rate
        if place:
            n_lines = random.choices([1, 2, 3, 4, 5], [45, 28, 15, 8, 4])[0]
            mobile_share = 0.30 + 0.25 * ((d - START).days / (END - START).days)
            sales_ch = "mobile_app" if random.random() < mobile_share else "web"
            promo = None
            if first and random.random() < 0.45:
                promo = "WELCOME10"
            elif d.month in (11, 12) and random.random() < 0.35:
                promo = "HOLIDAY20"
            elif d.year == 2025 and d.month in (3, 6, 9) and random.random() < 0.30:
                promo = "FLASH30"
            elif random.random() < 0.05:
                promo = "FREESHIP"
            disc = {"WELCOME10": .10, "HOLIDAY20": .20, "FLASH30": .30}.get(promo, 0)
            if promo == "FLASH30":
                n_lines = max(n_lines, random.choice([2, 3, 4]))
            status = "delivered"
            if random.random() < 0.035:
                status = "cancelled"
            elif (END - d).days < 7:
                status = "shipped"
            subtotal, lines = 0, []
            for p in pick_products(d, n_lines):
                cat, price, _, _ = product_meta[p]
                qty = random.choices([1, 2, 3], [80, 15, 5])[0]
                if price < 40 and random.random() < .3:
                    qty += 1
                price = price_on(p, d)
                lines.append((iid, oid, p, qty, price, disc))
                subtotal += qty * price * (1 - disc)
                # returns
                if status == "delivered":
                    r = 0.18 if cat == "Footwear" else 0.045
                    if promo == "FLASH30":
                        r += 0.06
                    if random.random() < r:
                        rd = d + timedelta(days=random.randint(5, 30))
                        reasons = RETURN_REASONS.get(cat, RETURN_REASONS["_default"])
                        refund = round(qty * price * (1 - disc), 2)
                        if rd <= END + timedelta(days=30):
                            returns_.append((rid, iid, rd, random.choice(reasons), refund,
                                             random.choice(cs_reps) if random.random() > .03 else None))
                            rid += 1
                iid += 1
            fee = 0.0 if (subtotal >= 75 or promo == "FREESHIP") else 6.99
            touched = d + timedelta(days=random.randint(2, 6) if status != "cancelled" else 1)
            orders.append((oid, cid, d, status, sales_ch, promo, fee, f"{touched} {random.randint(6,21):02d}:{random.randint(0,59):02d}:00"))
            items.extend(lines)
            oid += 1
            first = False
            d += timedelta(days=random.randint(3, 20))
        else:
            d += timedelta(days=1)

orders.sort(key=lambda o: (o[2], o[0]))
# customer updated_at: signup time, or a later profile edit for some
for c in customers:
    upd = c[6] + timedelta(days=random.randint(0, 400) if random.random() < .3 else 0)
    c.append(f"{min(upd, END)} {random.randint(6,23):02d}:{random.randint(0,59):02d}:00")
products = [p + (f"{price_change[p[0]][0] if p[0] in price_change else p[5]} 09:00:00",) for p in products]

with OUT.open("w") as f:
    f.write("-- Seed data for Northbrook Outfitters (generated by scripts/generate_data.py, seed 42)\n")
    f.write("SET search_path TO retail;\nBEGIN;\n\n")
    insert(f, "employees", ["employee_id","first_name","last_name","title","department","manager_id","hire_date"], employees)
    insert(f, "categories", ["category_id","category_name"], categories)
    insert(f, "products", ["product_id","product_name","category_id","unit_price","unit_cost","launch_date","is_active","updated_at"], products)
    insert(f, "product_price_history", ["product_id","unit_price","effective_from","effective_to"], price_history)
    insert(f, "customers", ["customer_id","first_name","last_name","email","city","state","signup_date","acquisition_channel","updated_at"], customers)
    insert(f, "orders", ["order_id","customer_id","order_date","status","sales_channel","promo_code","shipping_fee","updated_at"], sorted(orders))
    insert(f, "order_items", ["order_item_id","order_id","product_id","quantity","unit_price","discount_pct"], items)
    insert(f, "returns", ["return_id","order_item_id","return_date","reason","refund_amount","processed_by"], returns_)
    f.write("COMMIT;\n")

print(f"customers={len(customers)} products={len(products)} orders={len(orders)} "
      f"items={len(items)} returns={len(returns_)} -> {OUT}")
