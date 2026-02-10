
// Dublin Cycle Counters—Rhythm & Geography (Jan–Jun 2025)
// single file Processing sketch
//
// data
//  cycle-counts-1-jan-9-june-2025.csv
//  dublin-city-cycle-counter-locations.csv
//   dublin_dark_map.png
//
// idea is :left = small multiples radial(24h rhythm)
//       right = map bubbles for selected hour
//       bottom-right =ranked daily totals bar chart

import java.text.*;      // date parsing (timestamps)
import java.util.*;      // arrays, calendar
import java.io.File;     // (just for font file existence check)
boolean autoSaved = false;
int runStartMs; // just for timing when the output png is shot , becuase i want to show
                // innteractive things too in the report
// files
final String COUNTS_FILE = "cycle-counts-1-jan-9-june-2025.csv";
final String LOCS_FILE   = "dublin-city-cycle-counter-locations.csv";
final String MAP_FILE    = "dublin_dark_map.png";
// optional fonts (if not present it uses system font)
final String FONT_REG_FILE  = "Inter-Regular.ttf";
final String FONT_BOLD_FILE = "Inter-SemiBold.ttf";
// basic sizes 
final int UI_SIZE      = 15;
final int UI_SMALL     = 12;
final int UI_TINY      = 11;
final int TITLE_SIZE   = 22;
final int SUBTITLE_SZ  = 12;
//animations
final int BAR_ANIM_MS    = 3200;
final int BUBBLE_ANIM_MS = 900;
//  stations
final String[] STATION_NAMES = {
  "Grove Road Totem",
  "Clontarf - James Larkin Rd",
  "Clontarf - Pebble Beach Carpark",
  "Griffith Avenue (Clare Rd Side)",
  "Griffith Avenue (Lane Side)",
  "Richmond Street Outbound"
};

// columns for each station in the counts CSV
final String[][] STATION_COUNT_COLUMNS = {
  { "Grove Road Totem", "Grove Road Totem OUT", "Grove Road Totem IN" },
  { "Clontarf - James Larkin Rd",
    "Clontarf - James Larkin Rd Cyclist West",
    "Clontarf - James Larkin Rd Cyclist East" },
  { "Clontarf - Pebble Beach Carpark",
    "Clontarf - Pebble Beach Carpark Cyclist West",
    "Clontarf - Pebble Beach Carpark Cyclist East" },
  { "Griffith Avenue (Clare Rd Side)",
    "Griffith Avenue (Clare Rd Side) Cyclist South",
    "Griffith Avenue (Clare Rd Side) Cyclist North" },
  { "Griffith Avenue (Lane Side)",
    "Griffith Avenue (Lane Side) Cyclist South",
    "Griffith Avenue (Lane Side) Cyclist North" },
  { "Richmond Street Outbound",
    "Richmond Street Outbound Cyclist North",
    "Richmond Street Outbound Cyclist South" }
};
final int NUM_STATIONS =STATION_NAMES.length;
final int HOURS = 24;

//  data tables 
Table countsTable;
Table locsTable;

// station model
class Station {
  String name;
  float lat = Float.NaN, lon = Float.NaN; // from locations csv
  String[] cols;                          // which columns in counts csv belong to it
  Station(String n, String[] c) { name=n; cols=c; }
}
Station[] stations = new Station[NUM_STATIONS];
// aggregates 
// mean cyclists/hr per hour, split weekday vs weekend
float[][] hourlyMeanWeekday = new float[NUM_STATIONS][HOURS];
float[][] hourlyMeanWeekend = new float[NUM_STATIONS][HOURS];

// derived summaries for bar + tooltip
float[] dailyTotalWeekday  = new float[NUM_STATIONS];
float[] dailyTotalWeekend = new float[NUM_STATIONS];
float[] morningShareWeekday = new float[NUM_STATIONS];
float[] morningShareWeekend = new float[NUM_STATIONS];

float maxHourlyWeekday = 0;
float maxHourlyWeekend = 0;

//map
PImage basemap;
float mapX, mapY, mapW, mapH;
float mapMinLat, mapMaxLat, mapMinLon, mapMaxLon;

// projected station positions (pixels)
float[] stationMapX =new float[NUM_STATIONS];
float[] stationMapY =new float[NUM_STATIONS];

//  manual nudges (PIXELS) for each station on map
// background image isn’t perfectly geo-accurate,
// lat/lon mapping can be “almost” right but not exact.
// So i can nudge each station slightly by editing these.
// Order matches STATION_NAMES[] exactly.
float[] stationNudgeX = { 150, 40, 50, 30, 30, 190 };
float[] stationNudgeY = { 40, -40, -15, 75, 74, 30 };

//  layout 
float leftMargin = 50;
float rightPanelX;
float wheelRadius;
PVector[] wheelCenters = new PVector[NUM_STATIONS];
// legend box
float legendBoxX, legendBoxY, legendBoxW, legendBoxH;
// tooltip sizing
float tooltipBoxH =138;
// slider
float sliderX, sliderY, sliderW, sliderH;
boolean draggingSlider =false;

// bar chart region
float barPanelX, barPanelY, barPanelW, barPanelH;
int hoveredBar = -1;
// show-values button
boolean showAllMapValues = false;
float valueBtnX, valueBtnY, valueBtnW, valueBtnH;
// state 
boolean weekendMode = false;   // false weekdays, true weekends
int currentHour = 8;           // 0..23
int hoveredStation = -1;
int selectedStation = 0;
boolean normalizeRadials = false;

// fonts 
PFont fontUI, fontUIBold, fontTitle;

// colours
int bgCol     = color(10);
int textCol     = color(235);
int subTextCol   = color(185);
int gridCol    = color(75);
int spokeCol     = color(210);
int morningCol  = color(240, 190, 70);
int highlightCol = color(255);
int panelBg     = color(18, 180);
int tooltipBg   = color(0, 210);
//map ramp endpoints (blue -> yellow)
color rampLow  = color(120, 150, 230);
color rampHigh = color(240, 190, 70);
//window resize tracking (just so layout updates)
int prevW = -1, prevH = -1;
//animations state
int barAnimStartMs = 0;
int bubbleAnimStartMs = 0;
int lastAnimHour = -999;
boolean lastAnimWeekend = false;
float[] bubbleR   = new float[NUM_STATIONS];
float[] bubbleStart  = new float[NUM_STATIONS];
float[] bubbleTarget = new float[NUM_STATIONS];
// setup

void setup() {
  size(1600, 900, P2D);
  smooth(8);
  pixelDensity(displayDensity());
  surface.setResizable(true);
  surface.setTitle("Dublin Cycle Counters — Rhythm & Geography (Jan–Jun 2025)");

  // fonts: try load from data/,
  fontUI     = loadFontFromDataOrSystem(FONT_REG_FILE,  "SansSerif", UI_SIZE);
  fontUIBold = loadFontFromDataOrSystem(FONT_BOLD_FILE, "SansSerif", UI_SIZE);
  fontTitle  = loadFontFromDataOrSystem(FONT_BOLD_FILE, "SansSerif", TITLE_SIZE);
  textFont(fontUI);

  // load tables/images
  countsTable = loadTable(COUNTS_FILE, "header");
  locsTable   = loadTable(LOCS_FILE, "header");
  basemap     = loadImage(MAP_FILE);

  // build station objects (names + column lists)
  for (int i=0; i<NUM_STATIONS; i++)
    stations[i] = new Station(STATION_NAMES[i], STATION_COUNT_COLUMNS[i]);

  // attach lat/lon from the locations csv (by exact name match)
  attachLocations();

  // compute all the means (this is the “big” data step)
  computeAggregates();

  // compute layout and map projection
  recomputeLayout();
  prevW = width; prevH = height;

  // start animations
  barAnimStartMs = millis();
  restartBubbleAnim(true);
  runStartMs = millis();
}


// fonts helper
PFont loadFontFromDataOrSystem(String dataFile, String systemName, int size) {
  try {
    File f = new File(dataPath(dataFile));
    if (f.exists()) return createFont(dataFile, size, true);
  } catch(Exception e) { /* ignore */ }

  return createFont(systemName, size, true);
}

// 
// layout (positions of panels)
//
void recomputeLayout() {
  rightPanelX = width * 0.58;

  // legend box (left)
  legendBoxX = leftMargin;
  legendBoxY = 92;
  legendBoxW = rightPanelX - leftMargin - 30;
  legendBoxH = 74;

  // wheels area sizing
  float wheelsW = rightPanelX - leftMargin*2;
  wheelRadius = min(wheelsW/3.8, (height - 260)/2.8) * 0.48;

  computeWheelCenters();

  //map panel
  mapW = width - rightPanelX - 80;
  mapH = (height * 0.44);
  mapX = rightPanelX + 40;
  mapY = 180;

  //show-values button (top right of map)
  valueBtnW = 116;
  valueBtnH = 24;
  valueBtnX = mapX + mapW - valueBtnW;
  valueBtnY = 88;

  //slider under map
  sliderW = mapW * 0.92;
  sliderX = mapX + (mapW - sliderW)/2.0;
  sliderY = mapY + mapH + 28;
  sliderH = 12;

  // bars panel under slider
  barPanelX = mapX;
  barPanelY = sliderY + 44;
  barPanelW = mapW;
  barPanelH = height - barPanelY - 50;

  // map bounds depends on lat/lon, so do it after map size is known
  computeMapBounds();
  mapStationsToPixels();
}

// wheel centers: 3 columns x 2 rows
void computeWheelCenters() {
  int cols = 3;
  int rows = 2;

  float leftW = rightPanelX - leftMargin*2;
  float cellW = leftW / cols;

  float gridTop    = legendBoxY + legendBoxH + 46;
  float gridBottom = height - tooltipBoxH - 32;
  float cellH = max(140, (gridBottom - gridTop) / rows);

  float rowGap = 10; // slightly tighter

  int idx = 0;
  for (int r=0; r<rows; r++) {
    for (int c=0; c<cols; c++) {
      if (idx >= NUM_STATIONS) break;
      float cx = leftMargin + cellW*(c + 0.5);
      float cy = gridTop + cellH*(r + 0.5) + r*rowGap;
      wheelCenters[idx] = new PVector(cx, cy);
      idx++;
    }
  }
}

// 
// some small helpers
// 
float easeOutCubic(float t) {
  t = constrain(t, 0, 1);
  float u = 1 - t;
  return 1 - u*u*u;
}

float easeInOutCubic(float t) {
  t = constrain(t, 0, 1);
  return (t < 0.5) ? 4*t*t*t : 1 - pow(-2*t + 2, 3)/2.0;
}

void restartBarAnim() {
  barAnimStartMs = millis();
}

// bubble animation starts “from previous radius” or from zero
void restartBubbleAnim(boolean forceFromZero) {
  bubbleAnimStartMs = millis();
  for (int s=0; s<NUM_STATIONS; s++) bubbleStart[s] = forceFromZero ? 0 : bubbleR[s];
  lastAnimHour = currentHour;
  lastAnimWeekend = weekendMode;
}

// 
// loading locations
// 
// reads LOCS_FILE and matches station name exactly to “Bike Counter Locations”
void attachLocations() {

  // try typical column names first
  String nameCol = (locsTable.getColumnIndex("Bike Counter Locations") != -1) ? "Bike Counter Locations" : null;
  String latCol  = (locsTable.getColumnIndex("Latitude") != -1) ? "Latitude" : null;
  String lonCol  = (locsTable.getColumnIndex("Longitude") != -1) ? "Longitude" : null;

  // if the file has slightly different headers, try “contains”
  if (nameCol == null) nameCol = findFirstColumnLike(locsTable, new String[]{ "bike", "counter", "location", "name" });
  if (latCol  == null) latCol  = findFirstColumnLike(locsTable, new String[]{ "lat" });
  if (lonCol  == null) lonCol  = findFirstColumnLike(locsTable, new String[]{ "lon", "lng" });

  for (int i=0; i<NUM_STATIONS; i++) {
    String target = stations[i].name;

    for (TableRow row : locsTable.rows()) {
      String locName = row.getString(nameCol);
      if (locName != null && locName.trim().equals(target)) {
        stations[i].lat = row.getFloat(latCol);
        stations[i].lon = row.getFloat(lonCol);
        break;
      }
    }
  }
}

// helper: find column with hints
String findFirstColumnLike(Table t, String[] hints) {
  String[] cols = t.getColumnTitles();
  for (String c : cols) {
    if (c == null) continue;
    String lc = c.toLowerCase();
    for (String h : hints) if (lc.contains(h)) return c;
  }
  return cols.length > 0 ? cols[0] : null;
}

// 
// timestamp parsing (kept robust but no debug scaffolding)
// 
// the csv timestamps sometimes come as dd-MM-yyyy HH:mm so accepted a few patterns
Date parseTimestampMulti(String ts) {
  if (ts == null) return null;
  ts = ts.trim();
  if (ts.length() == 0) return null;

  // clean some typical junk: Z, fractions, timezone suffix etc.
  String cleaned = ts.replace("Z", "");
  int dot = cleaned.indexOf('.');
  if (dot != -1) cleaned = cleaned.substring(0, dot);

  int plus = cleaned.indexOf('+');
  if (plus != -1) cleaned = cleaned.substring(0, plus);

  int tPos = cleaned.indexOf('T');
  if (tPos == -1) tPos = cleaned.indexOf(' ');
  if (tPos != -1) {
    int dashAfterTime = cleaned.indexOf('-', tPos);
    if (dashAfterTime != -1) cleaned = cleaned.substring(0, dashAfterTime);
  }

  String[] patterns = {
    "yyyy-MM-dd'T'HH:mm:ss",
    "yyyy-MM-dd'T'HH:mm",
    "yyyy-MM-dd HH:mm:ss",
    "yyyy-MM-dd HH:mm",
    "dd-MM-yyyy HH:mm:ss",
    "dd-MM-yyyy HH:mm",
    "dd/MM/yyyy HH:mm:ss",
    "dd/MM/yyyy HH:mm",
    "MM/dd/yyyy HH:mm:ss",
    "MM/dd/yyyy HH:mm"
  };

  for (String p : patterns) {
    try {
      SimpleDateFormat fmt = new SimpleDateFormat(p);
      fmt.setLenient(false);
      return fmt.parse(cleaned);
    } catch(Exception e) { /* try next */ }
  }
  return null;
}

// reading counts + computing means 

void computeAggregates() {

  // sums and counts so we can compute mean
  float[][] sumW = new float[NUM_STATIONS][HOURS];
  float[][] sumE = new float[NUM_STATIONS][HOURS];
  int[][]   cntW = new int[NUM_STATIONS][HOURS];
  int[][]   cntE = new int[NUM_STATIONS][HOURS];

  // pick a time column (usually "Time")
  String timeCol = "Time";
  if (countsTable.getColumnIndex(timeCol) == -1) {
    // trying to guess if it has different casing
    String[] cols = countsTable.getColumnTitles();
    for (String c : cols) {
      if (c != null && (c.toLowerCase().contains("time") || c.toLowerCase().contains("date"))) {
        timeCol = c;
        break;
      }
    }
  }

  Calendar cal = Calendar.getInstance();

  //go row by row in counts csv
  for (TableRow row : countsTable.rows()) {
    String tstr = null;
    try { tstr = row.getString(timeCol); } catch(Exception e) { tstr=null; }

    Date d = parseTimestampMulti(tstr);
    if (d == null) continue;

    cal.setTime(d);

    int hour = cal.get(Calendar.HOUR_OF_DAY);   // 0..23
    int dow  = cal.get(Calendar.DAY_OF_WEEK);   // sunday..saturday
    boolean isWeekend = (dow == Calendar.SATURDAY || dow == Calendar.SUNDAY);

    //for each station, sum its two direction columns etc.
    for (int s=0; s<NUM_STATIONS; s++) {
      float v = 0;

      // dd all columns that belong to this station
      //(this is slightly shrewd because the CSV has separate IN/OUT columns)
      for (String col : stations[s].cols) {
        if (countsTable.getColumnIndex(col) == -1) continue;

        // many cells are blank->try/catch avoids crash
        try {
          float x = row.getFloat(col);
          if (!Float.isNaN(x)) v += x;
        } catch(Exception e) {
          // ignore blanks
        }
      }

      if (v <= 0) continue;

      if (isWeekend) {
        sumE[s][hour] += v;
        cntE[s][hour] += 1;
      } else {
        sumW[s][hour] += v;
        cntW[s][hour] += 1;
      }
    }
  }

  // compute means + maxima
  maxHourlyWeekday = 0;
  maxHourlyWeekend = 0;

  for (int s=0; s<NUM_STATIONS; s++) {
    for (int h=0; h<HOURS; h++) {
      hourlyMeanWeekday[s][h] = (cntW[s][h] > 0) ? (sumW[s][h] / cntW[s][h]) : 0;
      hourlyMeanWeekend[s][h] = (cntE[s][h] > 0) ? (sumE[s][h] / cntE[s][h]) : 0;

      maxHourlyWeekday = max(maxHourlyWeekday, hourlyMeanWeekday[s][h]);
      maxHourlyWeekend = max(maxHourlyWeekend, hourlyMeanWeekend[s][h]);
    }
  }

  // daily totals+morning share(07–10)
  for (int s=0; s<NUM_STATIONS; s++) {
    float totalW = 0, totalE = 0;
    float mornW  = 0, mornE  = 0;

    for (int h=0; h<HOURS; h++) {
      totalW += hourlyMeanWeekday[s][h];
      totalE += hourlyMeanWeekend[s][h];

      if (h >= 7 && h <= 10) {
        mornW += hourlyMeanWeekday[s][h];
        mornE += hourlyMeanWeekend[s][h];
      }
    }

    dailyTotalWeekday[s] = totalW;
    dailyTotalWeekend[s] = totalE;

    morningShareWeekday[s] = (totalW > 0.0001) ? (mornW / totalW) : 0;
    morningShareWeekend[s] = (totalE > 0.0001) ? (mornE / totalE) : 0;
  }
}


// map bounds & station projection

void computeMapBounds() {
  mapMinLat =  999;
  mapMaxLat = -999;
  mapMinLon =  999;
  mapMaxLon = -999;

  for (int s=0; s<NUM_STATIONS; s++) {
    if (Float.isNaN(stations[s].lat) || Float.isNaN(stations[s].lon)) continue;
    mapMinLat = min(mapMinLat, stations[s].lat);
    mapMaxLat = max(mapMaxLat, stations[s].lat);
    mapMinLon = min(mapMinLon, stations[s].lon);
    mapMaxLon = max(mapMaxLon, stations[s].lon);
  }

  // addign margins so points don’t sit on the edge
  float latMargin = (mapMaxLat - mapMinLat) * 0.18;
  float lonMargin = (mapMaxLon - mapMinLon) * 0.18;
  mapMinLat -= latMargin;
  mapMaxLat += latMargin;
  mapMinLon -= lonMargin;
  mapMaxLon += lonMargin;
}

void mapStationsToPixels() {
  for (int s=0; s<NUM_STATIONS; s++) {

    float lon = stations[s].lon;
    float lat = stations[s].lat;

    // lon -> x
    float x = map(lon, mapMinLon, mapMaxLon, mapX, mapX + mapW);

    // lat -> y (inverted because screen y increases downwards)
    float y = map(lat, mapMaxLat, mapMinLat, mapY, mapY + mapH);

    // applying manual pixel nudges here
    stationMapX[s] = x + stationNudgeX[s];
    stationMapY[s] = y + stationNudgeY[s];
  }
}


// drawing loop

void draw() {
  if (width != prevW || height != prevH) {
    prevW = width; prevH = height;
    recomputeLayout();
  }
  if (!autoSaved && millis() - runStartMs > 15000) {   // 15 seconds
  saveFrame("exported.png");   // unique filename each run
  autoSaved = true;
}

  background(bgCol);

  hoveredStation= -1;
  hoveredBar   = -1;

  drawHeader();
  drawModeToggle();
  drawRadialLegendBox();
  drawRadialWheels();
  drawMapPanel();
  drawSlider();
  drawBarPanel();
  drawTooltip();
}

// header
void drawHeader() {
  textAlign(LEFT, TOP);

  fill(textCol);
  textFont(fontTitle);
  textSize(TITLE_SIZE);
  text("Dublin Cycle Counters — Rhythm & Geography (Jan–Jun 2025)", leftMargin, 18);

  textFont(fontUI);
  textSize(SUBTITLE_SZ);
  fill(subTextCol);
  text("Left: mean 24-hour rhythm (radial spokes). Right: map at selected hour. Bottom-right: ranked station comparison (mean daily total).",
       leftMargin, 46);

  float y = 64;
  float x = leftMargin;
  fill(subTextCol);
  textSize(UI_SMALL);

  text("Toggle:", x, y); x += textWidth("Toggle:") + 10;
  x = drawKeycap("W", x, y-2); x += 6;
  text("/", x, y); x += textWidth("/") + 6;
  x = drawKeycap("E", x, y-2); x += 14;

  text("Hour:", x, y); x += textWidth("Hour:") + 10;
  x = drawKeycap("←", x, y-2); x += 6;
  x = drawKeycap("→", x, y-2); x += 14;

  text("Select:", x, y); x += textWidth("Select:") + 8;
  text("click map circle, bar, or wheel", x, y); x += textWidth("click map circle, bar, or wheel") + 14;

  text("Normalise:", x, y); x += textWidth("Normalise:") + 10;
  x = drawKeycap("N", x, y-2);

  if (normalizeRadials) {
    x += 10;
    fill(morningCol);
    textFont(fontUIBold);
    text("Normalised", x, y);
    textFont(fontUI);
  }
}

float drawKeycap(String label, float x, float y) {
  textFont(fontUIBold);
  textSize(UI_TINY);

  float padX = 10;
  float w = textWidth(label) + padX*2;
  float h = 22;

  noStroke();
  fill(255, 40);
  rect(x, y, w, h, 6);

  stroke(255, 60);
  noFill();
  rect(x, y, w, h, 6);

  fill(textCol);
  textAlign(CENTER, CENTER);
  text(label, x + w/2, y + h/2 + 0.5);

  textFont(fontUI);
  textAlign(LEFT, TOP);
  return x + w;
}

// mode toggle pills
void drawModeToggle() {
  float x = mapX;
  float y = 60;

  textFont(fontUI);
  textSize(UI_SMALL);
  textAlign(LEFT, TOP);

  fill(textCol);
  text("Mode:", x, y);

  float bx = x + textWidth("Mode:") + 10;
  bx = drawModePill("Weekdays", bx, y-2, !weekendMode);
  bx += 10;
  drawModePill("Weekends", bx, y-2, weekendMode);
}

float drawModePill(String txt, float x, float y, boolean active) {
  textFont(active ? fontUIBold : fontUI);
  textSize(UI_TINY);

  float w = textWidth(txt) + 18;
  float h = 22;

  noStroke();
  fill(active ? color(255, 60) : color(255, 25));
  rect(x, y, w, h, 999);

  stroke(active ? color(255, 120) : color(255, 50));
  noFill();
  rect(x, y, w, h, 999);

  fill(active ? textCol : subTextCol);
  textAlign(CENTER, CENTER);
  text(txt, x + w/2, y + h/2 + 0.5);

  textAlign(LEFT, TOP);
  textFont(fontUI);
  return x + w;
}

// radial legend box

void drawRadialLegendBox() {
  noStroke();
  fill(panelBg);
  rect(legendBoxX, legendBoxY, legendBoxW, legendBoxH, 12);
  textFont(fontUI);
  textAlign(LEFT, TOP);
  textSize(UI_SMALL);
  fill(textCol);
  text("Radial spokes:", legendBoxX+12, legendBoxY+10);

  fill(subTextCol);
  text("Angle = hour (0 at top, clockwise)", legendBoxX+140, legendBoxY+10);

  String lenLine = normalizeRadials
    ? "Length = mean cyclists/hr (normalised per station)"
    : "Length = mean cyclists/hr (global scale within mode)";
  text(lenLine, legendBoxX+140, legendBoxY+30);

  fill(subTextCol);
  text("Yellow spokes = 07:00–10:00", legendBoxX+140, legendBoxY+50);

  // mini ring legend (to the right)
  float cx = legendBoxX + legendBoxW - 185;
  float cy = legendBoxY + legendBoxH/2 + 2;
  float r  = 22;

  float modeMax = weekendMode ? maxHourlyWeekend : maxHourlyWeekday;
  modeMax = max(1, modeMax);

  float[] fracs = {0.25, 0.50, 0.75, 1.00};

  strokeWeight(1.6);
  noFill();
  for (int i=0; i<fracs.length; i++) {
    float f = fracs[i];
    stroke(lerpColor(rampLow, rampHigh, f), 160);
    float rr = r * (0.80 + 0.55*i);
    ellipse(cx, cy, rr*2, rr*2);
  }

  textAlign(LEFT, CENTER);
  textFont(fontUI);
  textSize(UI_TINY);

  float lx = cx + r*2 + 12;
  float ly = cy - 16;

  for (int i=0; i<fracs.length; i++) {
    float f = fracs[i];
    fill(lerpColor(rampLow, rampHigh, f));

    String lab = normalizeRadials ? nf(f, 0, 2) : str(round(modeMax * f));
    text(lab, lx, ly + i*12.2);
  }

  fill(subTextCol);
  if (!normalizeRadials) text("cyc/hr", lx + 46, ly + (fracs.length-1)*12.2);
}

// radial wheels
void drawRadialWheels() {
  float[][] hourly = weekendMode ? hourlyMeanWeekend : hourlyMeanWeekday;
  float modeMax = weekendMode ? maxHourlyWeekend : maxHourlyWeekday;
  modeMax = max(1e-6, modeMax);

  for (int s=0; s<NUM_STATIONS; s++) {
    PVector c = wheelCenters[s];
    float maxR = wheelRadius;
    float ringStep = maxR / 4.0;

    float d = dist(mouseX, mouseY, c.x, c.y);
    boolean isHover = (d < maxR*1.02);
    if (isHover) hoveredStation = s;

    float stationMax = 0;
    if (normalizeRadials) {
      for (int h=0; h<HOURS; h++) stationMax = max(stationMax, hourly[s][h]);
      stationMax = max(1e-6, stationMax);
    }

    // rings
    noFill();
    stroke(gridCol);
    strokeWeight(1);
    for (int i=1; i<=4; i++) ellipse(c.x, c.y, ringStep*2*i, ringStep*2*i);

    // axes
    stroke(gridCol);
    line(c.x - maxR, c.y, c.x + maxR, c.y);
    line(c.x, c.y - maxR, c.x, c.y + maxR);

    // ticks around
    float tickInner = maxR + 4;
    for (int h=0; h<HOURS; h++) {
      float ang = -HALF_PI + TWO_PI * (h/(float)HOURS);
      float len = (h % 6 == 0) ? 9 : 4;
      stroke(h % 6 == 0 ? 140 : 95);

      float tx1 = c.x + cos(ang) * tickInner;
      float ty1 = c.y + sin(ang) * tickInner;
      float tx2 = c.x + cos(ang) * (tickInner + len);
      float ty2 = c.y + sin(ang) * (tickInner + len);
      line(tx1, ty1, tx2, ty2);
    }

    // spokes (one per hour)
    for (int h=0; h<HOURS; h++) {
      float val = hourly[s][h];
      if (val <= 0) continue;

      float denom = normalizeRadials ? stationMax : modeMax;
      float rr = map(val, 0, denom, 0, maxR);

      float angle = -HALF_PI + TWO_PI * (h/(float)HOURS);
      float x2 = c.x + cos(angle) * rr;
      float y2 = c.y + sin(angle) * rr;

      boolean isMorning = (h >= 7 && h <= 10);
      if (isMorning) {
        stroke(morningCol);
        strokeWeight(isHover ? 2.6 : 1.9);
      } else {
        stroke(spokeCol);
        strokeWeight(isHover ? 1.9 : 1.3);
      }
      line(c.x, c.y, x2, y2);
    }
    // title
    fill(textCol);
    textAlign(CENTER, BOTTOM);
    textFont(fontUIBold);
    textSize(UI_SMALL);
    text(stations[s].name, c.x, c.y - maxR - 24);

    // hour labels
    int[] tickHours = {0, 6, 12, 18};
    textAlign(CENTER, TOP);
    textFont(fontUIBold);
    textSize(UI_TINY);
    fill(textCol);
    for (int th : tickHours) {
      float ang = -HALF_PI + TWO_PI * (th/(float)HOURS);
      float tLabelR = maxR + 18;
      float tlx = c.x + cos(ang) * tLabelR;
      float tly = c.y + sin(ang) * tLabelR;
      text(th, tlx, tly);
    }
    textFont(fontUI);
    // selection halo
    if (selectedStation == s || hoveredStation == s) {
      noFill();
      stroke(selectedStation == s ? highlightCol : color(255, 150));
      strokeWeight(selectedStation == s ? 3.0 : 2.0);
      ellipse(c.x, c.y, maxR*2.18, maxR*2.18);
    }
  }
}
// map panel (BUBBLES + values)
void drawMapPanel() {
  float[][] hourly = weekendMode ? hourlyMeanWeekend : hourlyMeanWeekday;
  float modeMax = weekendMode ? maxHourlyWeekend : maxHourlyWeekday;
  modeMax = max(1, modeMax);

  // hour/mode changes -> restart grow anim
  if (currentHour != lastAnimHour || weekendMode != lastAnimWeekend) {
    bubbleAnimStartMs = millis();
    for (int s=0; s<NUM_STATIONS; s++) bubbleStart[s] = bubbleR[s];
    lastAnimHour = currentHour;
    lastAnimWeekend = weekendMode;
  }
  float tAnim = (millis() - bubbleAnimStartMs) / (float)BUBBLE_ANIM_MS;
  float a = easeOutCubic(constrain(tAnim, 0, 1));

  // small header
  fill(textCol);
  textAlign(LEFT, TOP);
  textFont(fontUIBold);
  textSize(13);
  float tx = mapX;
  float ty = 98;
  text("Map view", tx, ty);

  textFont(fontUI);
  textSize(UI_SMALL);
  fill(subTextCol);
  text("Circle size + colour encode mean cyclists/hr at selected hour (global scale within mode).", tx, ty+18);
  // show-values button
  drawSmallButton(valueBtnX, valueBtnY, valueBtnW, valueBtnH, "Show values", showAllMapValues);

  // ramp bar
  float rampW = 220;
  float rampH = 10;
  float rampX = mapX;
  float rampY = ty + 44;

  for (int i=0; i<rampW; i++) {
    float tt = i/(float)(rampW-1);
    stroke(lerpColor(rampLow, rampHigh, tt));
    line(rampX+i, rampY, rampX+i, rampY+rampH);
  }
  noStroke();
  fill(subTextCol);
  textAlign(LEFT, TOP);
  text("low", rampX, rampY + rampH + 4);
  textAlign(RIGHT, TOP);
  text("high", rampX + rampW, rampY + rampH + 4);
  // map image background
  image(basemap, mapX, mapY, mapW, mapH);
  // compute target radii for this hour
  for (int s=0; s<NUM_STATIONS; s++) {
    float val = hourly[s][currentHour];
    bubbleTarget[s] = map(sqrt(max(0, val)), 0, sqrt(modeMax), 7, 42);
    bubbleR[s] = lerp(bubbleStart[s], bubbleTarget[s], a);
  }

  // draw bubbles + selection label (outside bubble)
  for (int s=0; s<NUM_STATIONS; s++) {
    float val = hourly[s][currentHour];
    float r = bubbleR[s];

    float tt = constrain(val / modeMax, 0, 1);
    tt = pow(tt, 0.70);
    int fillCol = lerpColor(rampLow, rampHigh, tt);
    float x = stationMapX[s];
    float y = stationMapY[s];
    float d = dist(mouseX, mouseY, x, y);
    boolean isHover = (d <= max(r, 12));
    if (isHover) hoveredStation = s;

    // bubble
    noStroke();
    fill(fillCol, 210);
    ellipse(x, y, r*2, r*2);
    // outlines for hover/selected
    if (selectedStation == s) {
      stroke(highlightCol);
      strokeWeight(3);
      noFill();
      ellipse(x, y, r*2 + 6, r*2 + 6);
    } else if (isHover) {
      stroke(220);
      strokeWeight(2);
      noFill();
      ellipse(x, y, r*2 + 4, r*2 + 4);
    }

    // try 1: selected station value  NOT inside bubble
    // drew it as a small callout box OUTSIDE (so tiny bubbles
    // don't get covered/overwritten i think maybe).
    // (Show-all mode still uses the callout system below)
    if (!showAllMapValues && selectedStation == s) {
      String txt = nf(round(val), 0);

      textFont(fontUIBold);
      textSize(UI_SMALL);
      float tw = textWidth(txt);
      float padX = 10;
      float padY = 6;
      float bw = tw + padX*2;
      float bh = 22;

      //default: to the right of bubble
      float gap = max(10, r*0.55);
      float bx = x + r + gap + bw/2;
      float by = y;

      //if too near right map edge, flip to left
      if (bx + bw/2 > mapX + mapW - 8) {
        bx = x - r - gap - bw/2;
      }
      //keep it inside vertically
      by = constrain(by, mapY + bh/2 + 6, mapY + mapH - bh/2 - 6);

      // leader line from bubble edge -> label box edge
      stroke(255, 140);
      strokeWeight(1.2);
      float sx = (bx > x) ? x + r : x - r;             // start at bubble edge
      float ex = (bx > x) ? bx - bw/2 : bx + bw/2;     // end at box edge
      line(sx, y, ex, by);
      //label box
      noStroke();
      fill(0, 170);
      rect(bx - bw/2, by - bh/2, bw, bh, 8);
      stroke(255, 70);
      noFill();
      rect(bx - bw/2, by - bh/2, bw, bh, 8);

      // text
      fill(textCol);
      textAlign(CENTER, CENTER);
      text(txt, bx, by + 0.5);

      textFont(fontUI);
    }
  }

  //show-all values
  if (showAllMapValues) drawMapValueCallouts(hourly);
}

void drawSmallButton(float x, float y, float w, float h, String label, boolean active) {
  noStroke();
  fill(active ? color(255, 60) : color(255, 25));
  rect(x, y, w, h, 999);
  stroke(active ? color(255, 120) : color(255, 50));
  strokeWeight(1);
  noFill();
  rect(x, y, w, h, 999);
  fill(active ? textCol : subTextCol);
  textAlign(CENTER, CENTER);
  textFont(active ? fontUIBold : fontUI);
  textSize(UI_TINY);
  text(label, x + w/2, y + h/2 + 0.5);
  textFont(fontUI);
}

// radial graphs colliding , moving it
void drawMapValueCallouts(float[][] hourly) {
  PVector[] labelPos = new PVector[NUM_STATIONS];
  // start placements: push a bit away from map center
  float cx = mapX + mapW/2;
  float cy = mapY + mapH/2;
  for (int s=0; s<NUM_STATIONS; s++) {
    float x = stationMapX[s];
    float y = stationMapY[s];

    PVector p = new PVector(x, y);

    PVector dir = new PVector(x - cx, y - cy);
    if (dir.mag() < 0.001) dir = new PVector(1, 0);
    dir.normalize();

    dir.mult(max(14, bubbleR[s]*0.65));
    p.add(dir);

    labelPos[s] = p;
  }

  // repel iterations
  float minD = 26;
  for (int it=0; it<10; it++) {
    for (int a=0; a<NUM_STATIONS; a++) {
      for (int b=a+1; b<NUM_STATIONS; b++) {
        float dx = labelPos[a].x - labelPos[b].x;
        float dy = labelPos[a].y - labelPos[b].y;
        float d = sqrt(dx*dx + dy*dy);
        if (d < 0.001) { dx = 1; dy = 0; d = 1; }
        if (d < minD) {
          float push = (minD - d) * 0.5;
          float ux = dx / d;
          float uy = dy / d;
          labelPos[a].x += ux * push;
          labelPos[a].y += uy * push;
          labelPos[b].x -= ux * push;
          labelPos[b].y -= uy * push;
        }
      }
    }
    // clamp inside map box
    for (int s=0; s<NUM_STATIONS; s++) {
      labelPos[s].x = constrain(labelPos[s].x, mapX + 12, mapX + mapW - 12);
      labelPos[s].y = constrain(labelPos[s].y, mapY + 12, mapY + mapH - 12);
    }
  }

  // draw callouts
  textFont(fontUIBold);
  textSize(UI_SMALL);

  for (int s=0; s<NUM_STATIONS; s++) {
    float val = hourly[s][currentHour];
    String txt = nf(round(val), 0);
    float bx = labelPos[s].x;
    float by = labelPos[s].y;
    float tw = textWidth(txt);
    float padX = 10;
    float bw = tw + padX*2;
    float bh = 22;

    // leader
    stroke(255, 120);
    strokeWeight(1.2);
    line(stationMapX[s], stationMapY[s], bx, by);
    // box
    noStroke();
    fill(0, 170);
    rect(bx - bw/2, by - bh/2, bw, bh, 8);
    stroke(255, 70);
    noFill();
    rect(bx - bw/2, by - bh/2, bw, bh, 8);
    // value
    fill(textCol);
    textAlign(CENTER, CENTER);
    text(txt, bx, by + 0.5);
  }
  textFont(fontUI);
}
// slider (hour selection)
void drawSlider() {
  noStroke();
  fill(70);
  rect(sliderX, sliderY, sliderW, sliderH, sliderH/2);

  float t = currentHour / 23.0;
  float hx = sliderX + t * sliderW;
  float hy = sliderY + sliderH/2;
  boolean over = dist(mouseX, mouseY, hx, hy) < 12;
  fill(over || draggingSlider ? morningCol : 230);
  stroke(0);
  strokeWeight(1.5);
  ellipse(hx, hy, 18, 18);

  fill(textCol);
  noStroke();
  textAlign(CENTER, TOP);
  textFont(fontUIBold);
  textSize(UI_SMALL);
  text("Selected hour: " + nf(currentHour, 2) + ":00", sliderX + sliderW/2, sliderY + sliderH + 6);
  textFont(fontUI);
}

// bars panel (ranked daily totals)

void drawBarPanel() {
  float x = barPanelX;
  float y = barPanelY;
  float w = barPanelW;
  float h = barPanelH;

  noStroke();
  fill(panelBg);
  rect(x, y, w, h, 12);

  textAlign(LEFT, TOP);
  textFont(fontUIBold);
  textSize(UI_SMALL);
  fill(textCol);

  String modeLabel = weekendMode ? "Weekends" : "Weekdays";
  text("Ranked station comparison (" + modeLabel + " mean daily total)", x+14, y+12);
  float[] daily = weekendMode ? dailyTotalWeekend : dailyTotalWeekday;
  // sort indices by daily value
  Integer[] idx = new Integer[NUM_STATIONS];
  for (int i=0; i<NUM_STATIONS; i++) idx[i] = i;

  Arrays.sort(idx, new Comparator<Integer>() {
    public int compare(Integer a, Integer b) {
      return Float.compare(daily[b], daily[a]); // descending
    }
  });
  float leftPad = 18;
  float topPad = 44;
  float rowH = min(38, (h - topPad - 24)/NUM_STATIONS);
  float labelW = 240;

  float barX =x + leftPad + labelW;
  float barW =w - leftPad - labelW - 80;

  float maxDaily = max(1, maxArray(daily));

  hoveredBar = -1;

  float animT = (millis() - barAnimStartMs) / (float)BAR_ANIM_MS;
  float anim = easeInOutCubic(constrain(animT, 0, 1));

  for (int r=0; r<NUM_STATIONS; r++) {
    int s = idx[r];
    float ry = y + topPad + r*rowH;
    boolean over = (mouseX > x && mouseX < x+w && mouseY > ry && mouseY < ry+rowH);
    if (over) hoveredBar = s;
    textAlign(LEFT, CENTER);
    textFont(over ? fontUIBold : fontUI);
    textSize(UI_SMALL);
    fill(over ? textCol : subTextCol);
    text(stations[s].name, x + leftPad, ry + rowH*0.55);

    float val = daily[s];
    float bw = map(val, 0, maxDaily, 0, barW) * anim;

    noStroke();
    fill(morningCol, 210);
    rect(barX, ry + rowH*0.25, bw, rowH*0.5, 8);

    if (selectedStation == s) {
      noFill();
      stroke(highlightCol);
      strokeWeight(2.5);
      rect(barX-2, ry + rowH*0.25-2, barW+4, rowH*0.5+4, 10);
    }
    fill(over ? textCol : subTextCol);
    textAlign(RIGHT, CENTER);
    textFont(fontUIBold);
    textSize(UI_SMALL);
    text(nf(round(val), 0), x + w - 18, ry + rowH*0.55);
  }
  textFont(fontUI);
}

float maxArray(float[] a) {
  float m = -1e9;
  for (float v : a) m = max(m, v);
  return m;
}


// tooltip box (details of selected/hovered station)

void drawTooltip() {
  int s = (hoveredStation >= 0) ? hoveredStation : selectedStation;
  if (s < 0) return;

  float[][] hourly = weekendMode ? hourlyMeanWeekend : hourlyMeanWeekday;
  float[] daily    = weekendMode ? dailyTotalWeekend : dailyTotalWeekday;
  float[] share    = weekendMode ? morningShareWeekend : morningShareWeekday;
  float maxVal = -1;
  int peakHour = 0;
  for (int h=0; h<HOURS; h++) {
    if (hourly[s][h] > maxVal) {
      maxVal = hourly[s][h];
      peakHour = h;
    }
  }
  String modeLabel = weekendMode ? "Weekends" : "Weekdays";
  String title = stations[s].name + "  (" + modeLabel + ")";
  int atVal = round(hourly[s][currentHour]);
  int pkVal = round(maxVal);
  int dtVal = round(daily[s]);
  int msPct = round(share[s] * 100.0);
  float pad = 14;
  float lineH = 19;
  float boxW = rightPanelX - leftMargin - 30;
  float boxH = tooltipBoxH;
  float boxX = leftMargin;
  float boxY = height - boxH - 18;
  noStroke();
  fill(tooltipBg);
  rect(boxX, boxY, boxW, boxH, 12);

  float tx = boxX + pad;
  float ty = boxY + pad;

  textAlign(LEFT, TOP);
  textFont(fontUIBold);
  textSize(13);
  fill(textCol);
  text(title, tx, ty);
  ty += 26;
  textFont(fontUI);
  textSize(UI_SMALL);

  drawKV("At " + nf(currentHour, 2) + ":00", atVal + " cyclists/hr", tx, ty); ty += lineH;
  drawKV("Peak hour", nf(peakHour, 2) + ":00  (" + pkVal + " cyclists/hr)", tx, ty); ty += lineH;
  drawKV("Mean daily total", dtVal + " cyclists/day", tx, ty); ty += lineH;
  drawKV("Morning share (07–10)", msPct + " %", tx, ty); ty += lineH;

  fill(subTextCol);
  textSize(UI_TINY);
  text("Lat/Lon: " + nf(stations[s].lat, 0, 4) + ", " + nf(stations[s].lon, 0, 4), tx, ty + 8);

  textFont(fontUI);}

void drawKV(String k, String v, float x, float y) {
  fill(subTextCol);
  textAlign(LEFT, TOP);
  text(k + ":", x, y);

  fill(textCol);
  textAlign(LEFT, TOP);
  text(v, x + 185, y);
}
// interaction

void mousePressed() {
  // show-values button click
  if (mouseX > valueBtnX && mouseX < valueBtnX + valueBtnW &&
      mouseY > valueBtnY && mouseY < valueBtnY + valueBtnH) {
    showAllMapValues = !showAllMapValues;
    return;
  }

  // mode pills click
  float labelX = mapX + textWidth("Mode:") + 10;
  float pillY = 58;

  float wW = textWidth("Weekdays") + 18;
  float wE = textWidth("Weekends") + 18;

  if (mouseY > pillY && mouseY < pillY + 22) {
    boolean prev = weekendMode;

    if (mouseX > labelX && mouseX < labelX + wW) weekendMode = false;
    if (mouseX > labelX + wW + 10 && mouseX < labelX + wW + 10 + wE) weekendMode = true;

    if (weekendMode != prev) {
      restartBarAnim();
      restartBubbleAnim(false);
    }
  }

  // radial wheel select
  for (int s=0; s<NUM_STATIONS; s++) {
    PVector c = wheelCenters[s];
    if (dist(mouseX, mouseY, c.x, c.y) <= wheelRadius*1.05) {
      selectedStation = s;
      return;
    }
  }

  // slider click/drag
  float t = currentHour / 23.0;
  float hx = sliderX + t * sliderW;
  float hy = sliderY + sliderH/2;

  if (dist(mouseX, mouseY, hx, hy) < 14 ||
      (mouseX > sliderX && mouseX < sliderX+sliderW && mouseY > sliderY-8 && mouseY < sliderY+sliderH+8)) {
    draggingSlider = true;
    int prevHour = currentHour;
    updateSliderFromMouse();
    if (currentHour != prevHour) restartBubbleAnim(false);
  } else draggingSlider = false;

  // map bubble select (uses animated radii)
  for (int s=0; s<NUM_STATIONS; s++) {
    float d = dist(mouseX, mouseY, stationMapX[s], stationMapY[s]);
    if (d <= max(bubbleR[s], 12)) {
      selectedStation = s;
      break;
    }
  }

  // bar select
  if (mouseX > barPanelX && mouseX < barPanelX + barPanelW &&
      mouseY > barPanelY && mouseY < barPanelY + barPanelH) {
    if (hoveredBar >= 0) selectedStation = hoveredBar;
  }
}

void mouseDragged() {
  if (draggingSlider) {
    int prevHour = currentHour;
    updateSliderFromMouse();
    if (currentHour != prevHour) restartBubbleAnim(false);
  }
}
void mouseReleased() {
  draggingSlider = false;
}

void updateSliderFromMouse() {
  float t = constrain((mouseX - sliderX) / sliderW, 0, 1);
  currentHour = round(t * 23);
}
void keyPressed() {
  if (key == 'w' || key == 'W') {
    if (weekendMode) { weekendMode = false; restartBarAnim(); restartBubbleAnim(false); }
  }
  else if (key == 'e' || key == 'E') {
    if (!weekendMode) { weekendMode = true; restartBarAnim(); restartBubbleAnim(false); }
  }
  else if (key == 'n' || key == 'N') {
    normalizeRadials = !normalizeRadials;
  }
  else if (keyCode == LEFT)  { int p=currentHour; currentHour = max(0, currentHour - 1); if (p!=currentHour) restartBubbleAnim(false); }
  else if (keyCode == RIGHT) { int p=currentHour; currentHour = min(23, currentHour + 1); if (p!=currentHour) restartBubbleAnim(false); }
}
