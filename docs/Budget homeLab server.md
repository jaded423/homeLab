**PERFECT approach!** This is actually the SMART way to do homelab. Start with what you have (free), learn what you actually need, then buy the right equipment. Way better than impulse-buying the wrong thing.

## Phase 1: Start NOW With What You Have (Free!)

### **Your Current Arsenal:**

- HP Pavilion x360 laptop(s)
- Raspberry Pi(s)
- (Presumably) external drives or can grab a cheap one

**This is enough to:**

- Learn Docker & containers
- Set up home DNS/ad-blocking
- Run file sharing
- Experiment with VMs
- Figure out what you ACTUALLY want to run

### **Suggested Starter Setup:**

**Raspberry Pi #1:**

- **Pi-hole** (network-wide ad blocking)
- **Unbound** (recursive DNS)
- Super low power, runs 24/7 perfectly
- Whole network benefits immediately

**Laptop #1 (Primary Server):**

- **Proxmox** or **Ubuntu Server**
- Run Docker containers:
    - Homepage dashboard
    - File sync (Syncthing/Nextcloud)
    - Media server (Jellyfin/Plex with local files)
    - Maybe small VMs for testing
- External drive connected via USB 3.0

**Raspberry Pi #2 (if you have it):**

- Network monitoring (Uptime Kuma)
- Backup DNS/Pi-hole
- Smart home hub (Home Assistant)
- Or just keep as spare

**Laptop #2 (if you have it):**

- Keep as desktop/work machine
- Or use for separate testing environment

### **Why This Works:**

✅ **Zero cost** - you're not buying anything you don't know you'll use ✅ **Low stakes** - experiment freely, break things, learn ✅ **Real experience** - same concepts as big servers, just smaller ✅ **Discover needs** - figure out what you actually want before spending

## Phase 2: Hunt for Tower Deals (Next 1-6 Months)

While learning on your current setup, watch for these:

### **Shopping List (Don't rush, wait for deals):**

**Priority 1: The Foundation ($100-150)**

- Dell Precision T3600 / T5810
- HP Z420 / Z620
- Dell OptiPlex 7020/9020 Tower (MT)

**What to look for:**

- Local pickup (save $30-50 on shipping)
- "Missing hard drive" listings (cheaper, you add your own)
- Corporate surplus sales (offices upgrading)
- Check: eBay, Craigslist, Facebook Marketplace, r/homelabsales

**Red flags to avoid:**

- "For parts/not working" unless you want a project
- No CPU or severely outdated CPU
- Damaged cases/missing critical parts

**Priority 2: Storage (Can wait)**

- Used enterprise HDDs: WD Red, Seagate IronWolf
- 4TB+ drives as you find deals
- Used 2-4TB drives: $20-40 each

**Priority 3: RAM (Upgrade later)**

- DDR3 ECC or non-ECC
- 8GB/16GB sticks as you find them cheap
- eBay lots often have good prices

**Priority 4: GPU (Last priority)**

- Used RTX 3060 12GB (~$200)
- Or wait - do you even need GPU compute yet?
- Let your laptop phase tell you if you need this

## Timeline Example:

**Month 0 (Now):**

- Set up Pi-hole on Raspberry Pi
- Install Proxmox on laptop
- Run a few containers
- Document what works/doesn't

**Month 1-2:**

- Keep using laptop setup
- Start monitoring eBay/Craigslist weekly
- Set price alerts
- Learn what you actually use vs. what sounded cool

**Month 3:**

- Find Dell T3600 for $120 local pickup
- Move main services to tower
- Keep laptop as backup/testing

**Month 4-6:**

- Add RAM when you hit limits ($50)
- Add storage drives as needed ($40 each)
- Laptop becomes travel/remote access point

**Month 6+:**

- Decide if you need GPU
- Expand storage if running media server
- Keep Pi-hole on Raspberry Pi (perfect device for this)

## What to Watch For (eBay Saved Searches):

Create these saved searches with email alerts:

```
"Dell Precision T3600" (local pickup)
"HP Z420 workstation" (price: $50-150)
"Dell OptiPlex 7020 tower" 
"Dell OptiPlex 9020 MT i7"
"server workstation lot" (sometimes great deals on multiples)
```

**Filter by:**

- Buy It Now (faster than auctions)
- Price: Low to High
- Distance: Nearest First (save on shipping)

## Things You'll Learn on Laptop Before Buying:

1. **Do you actually need 64GB RAM?**
    
    - Most homelabs run fine on 16-32GB
    - You'll see your actual usage
2. **What storage do you need?**
    
    - Running Plex? Need lots
    - Just containers? 1-2TB plenty
3. **GPU workloads?**
    
    - Want to run AI/LLMs? You'll know
    - Just Docker? Don't need it
4. **Power consumption matters**
    
    - Laptop uses 10-30W
    - Tower uses 50-200W
    - Is the electric bill worth it?
5. **Uptime requirements**
    
    - Is 24/7 important?
    - Can you tolerate restarts?

## Immediate Action Items:

**This weekend:**

1. Flash latest Raspberry Pi OS on one Pi
2. Install Pi-hole following their guide
3. Point your router DNS to the Pi
4. Install Proxmox on laptop (or Ubuntu Server if you prefer)
5. Run your first Docker container

**You'll learn more in one weekend of hands-on than months of reading.**

## My Advice:

**DON'T buy anything yet.**

Use your current gear for 2-4 weeks minimum. You'll quickly figure out:

- What you enjoy doing (containers vs VMs vs networking)
- What performance you actually need
- Whether homelab is even your thing
- What specific equipment makes sense

**THEN** when you find a T3600 for $100, you'll know exactly why you want it and how you'll use it.

This is seriously the perfect path. You're doing it right. Want help setting up Pi-hole or Proxmox on your current gear to get started?