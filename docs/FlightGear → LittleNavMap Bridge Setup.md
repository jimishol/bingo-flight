# 🛩️ FlightGear → LittleNavMap Bridge Setup (FGconnect Quickstart)

## 1. Download & Clone Required Tools

- Download LittleNavMap (latest `.tar.xz`):  
  **[https://github.com/albar965/littlenavmap](https://github.com/albar965/littlenavmap)**

- Clone FlightGear addon for LittleNavMap:  
  **[https://github.com/slawekmikula/flightgear-addon-littlenavmap](https://github.com/slawekmikula/flightgear-addon-littlenavmap)**

- Clone FGconnect:  
  **[https://github.com/Em-Ant/fgconnect](https://github.com/Em-Ant/fgconnect)**

- Install Python dependency (Python 3.13):  
  ```
  pip3 install xmltodict
  ```

---

## 2. Configure FlightGear Add‑on

In FlightGear:  
**Add‑ons → Little Nav Map**

```
Enable export:   true
Refresh rate:    10
UDP host:        localhost
UDP port:        7755
```

---

## 3. Run FGconnect (GUI Mode)

```
cd ~/games/git/fgconnect
python3 gui_tk.py
```

Inside FGconnect GUI:

```
FlightGear:
  IP:   127.0.0.1
  Port: 7755

LittleNavMap:
  IP:   127.0.0.1
  Port: 51968
```

Press **Start** on both connections.

---

## 4. Launch LittleNavMap

```
cd ~/games/flightgear-navigation_tools/LittleNavmap-linux-ubuntu-24.04-3.0.18
./littlenavmap
```

Then in LittleNavMap:

**Tools → Connect to Flight Simulator → Remote/Network**

```
IP address: 127.0.0.1
Port:       51968
```

In  ~/.local/share/applications I created fgnav.sh and fgnav.desktop so as to launch littlenavmap and its connection to flightgear by fnav desktop application.

Optionally from https://sourceforge.net/projects/red-griffin-atc/files/ I untared RedGriffinATC-2.3.0.tar.gz and add it to addons. (mbrola voices were tough to install so no festival package needed. Embedded flightgear's flite us fine.)
