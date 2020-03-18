import java.util.Map;
import java.util.LinkedHashMap;

boolean plotInRealTime = true;
int   maxSimTime = 120; // Seconds

int   populationSize = 200;
float chanceOfCatching = 0.1; // probability of contracting simuvirus from bumping into an infected circle
float chanceOfRecoveringWithoutSymtoms = 0.90; // chance to recover without developing symptoms
float chanceOfPassing = 0.035; // 3.5% across entire population
float chanceOfLosingImmunity = 0.01; // chance to lose immunity after contracting and recovering from simuvirus

// Todo:
// - age-related risk factor
// - different probability of transmission when asymptomatic vs symptomatic
// - social distancing
// - separate recovery or deceased

float meanTimeToBecomeSymptomaticOrRecoverWithoutSymptoms = 6; // avg # days to show symptoms after infection
float stdTimeToBecomeSymptomaticOrRecoverWithoutSymptoms = 2; // standard deviation from mean
float meanTimeToBecomeRecoveredOrDeseased = 6;
float stdTimeToBecomeRecoveredOrDeseased = 2;
float meanTimeToBecomeTotallyRecovered = 3;
float stdTimeToBecomeTotallyRecovered = 1;
float meanTimeToLoseImmunity = 4;
float stdTimeToLoseImmunity = 1;

int r = 15;
ArrayList<Individual> individuals = new ArrayList<Individual>(populationSize);
ArrayList<PopulationHealthSlice> phs = new ArrayList<PopulationHealthSlice>(120);

enum HealthState {
  Healthy,
  AsymptomaticButContagious,
  Symptomatic,
  RecoveredButContagious,
  RecoveredNotContagious,
  Deceased
}

PFont f;

//color healthy = color(144, 180, 210);
//color symptomatic = color(137, 162, 3);
//color recovered = color(225,105,180);
//color contagious = color(255,0,0);
//color notContagious = color(0,255,100);

color healthy = #1BB1FF;
color symptomatic = #FF5964;
color recovered = #FFFFFF;
color contagious = #FFE74C;
color notContagious = #6BF178;
color deceased = color(200,200,200);
//color deceased = color(0,0,0);

HashMap<HealthState, Integer> colorMap = new HashMap<HealthState, Integer>();

int slicesPerFrame = 2;
long startTime = 0;
long lastTime = 0;

void setup() 
{
  size(1294, 800);
  frameRate(120);
  f = createFont("Arial",16,true);
  textFont(f);
  
  colorMap.put(HealthState.Healthy, healthy);
  colorMap.put(HealthState.AsymptomaticButContagious, contagious);
  colorMap.put(HealthState.Symptomatic, symptomatic);
  colorMap.put(HealthState.RecoveredButContagious, recovered);
  colorMap.put(HealthState.RecoveredNotContagious, notContagious);
  colorMap.put(HealthState.Deceased, deceased);
  
  for (int i = 0; i < populationSize; i++) {
    individuals.add(new Individual(i, random(5, width-5), random(5, height-5), random(-PI, PI), random(1.0, 3.0)));
  }
  
  int randomSickIndividual = (int)random(0, populationSize);
  individuals.get(randomSickIndividual).setHealth(HealthState.AsymptomaticButContagious);
  startTime = millis();
}

int totalSeconds = 0;
boolean simFinished = false;
boolean drawLegend = true;
long prevTime = 0;
int slice = 0;


long frame = 0;

void draw()
{   
  frame++;
  
  if (!simFinished)
  {
    background(0);
    
    for (int i = 0; i < populationSize-1; i++)
    {
      Individual individual = individuals.get(i);
      for (int j = i+1; j < populationSize; j++)
      {
        individual.checkForContact(individuals.get(j));
      }
    }
    
    for (Individual individual : individuals) {
      individual.update(true);
    }
    
    int tNow = millis();
    if (tNow-lastTime > 250)
    {     
      PopulationHealthSlice ph = new PopulationHealthSlice(populationSize);
      
      for (Individual individual : individuals)
      {
        ph.update(individual);
      }
      
      phs.add(ph);
      
      simFinished = ph.simulationFinished() || (tNow - startTime > maxSimTime*1000);      
      lastTime = tNow;
    }
  }
  else if (!plotInRealTime)
  {
    if (slice+slicesPerFrame-1 < phs.size())
    {
      for (int i = 0; i<slicesPerFrame; i++)
      {
        int x = slice + 10;
        int y = 10;
        int verticalPixels = populationSize;
        PopulationHealthSlice p = phs.get(slice++);
        p.drawLine(x, y, verticalPixels, populationSize);
      }
    }
  }
  
  if (plotInRealTime && drawLegend)
  {
    int x = 10;
    int y = 10;
    int verticalPixels = populationSize;
    
    for (PopulationHealthSlice ph : phs)
    {
      ph.drawLine(x, y, verticalPixels, populationSize);
      x++;
    }
    
    drawLegend();
    drawLegend = !simFinished;
  }
}

class Individual
{  
  float xpos, ypos, movementAngle, movementSpeed;
  int radius = r;
  int id;
  
  public HealthState state;
  color healthColor;
  color contagiousColor;
  boolean willDie = false;
  boolean willRecoverWithoutSymptoms = false;
  boolean canBeReinfected = false;
  
  long timeBecameContagious = 0;
  long timeBecameSymptomatic = 0;
  long timeBecameRecovered = 0;
  long timeBecameHealthy = 0;
  long timeToBecomeSymptomaticOrRecoverWithoutSymptoms = 0;
  long timeToBecomeRecoveredOrDie = 0;
  long timeToBecomeTotallyRecovered = 0;
  long timeSinceLastChanceEvent = 0;
  long timeToLoseImmunity = 0;
  
  Individual (int id, float x, float y, float movementAngle, float movementSpeed) {  
    this.id = id;
    this.xpos = x;
    this.ypos = y;
    this.movementSpeed = movementSpeed;
    this.movementAngle = movementAngle;
    this.healthColor = healthy;
    this.contagiousColor = healthy;
    this.state = HealthState.Healthy;
  }
  
  public void setColor(color health, color contagious)
  {
    this.healthColor = health;
    this.contagiousColor = contagious;
  }
  
  public boolean isImmune()
  {
    return (this.state == HealthState.RecoveredButContagious ||
           this.state == HealthState.RecoveredNotContagious ||
           this.state == HealthState.Deceased);
  }
  
  public boolean isContagious()
  {
   return this.state == HealthState.AsymptomaticButContagious ||
          this.state == HealthState.Symptomatic ||
          this.state == HealthState.RecoveredButContagious; 
  }
  
  // Return time in ms
  private long getNormallyDistributedTime(float mean, float std)
  {
    return (long) max(0, 1000.0*(randomGaussian() * std + mean));
  }
  
  public void setHealth(HealthState state)
  {
    this.state = state;
    
    switch (this.state)
    {
      case Healthy:
          this.healthColor = healthy;
          this.contagiousColor = healthy;
          break;
      
      case AsymptomaticButContagious:
          this.healthColor = healthy;
          this.contagiousColor = contagious;
          this.timeBecameContagious = millis();
          this.timeToBecomeSymptomaticOrRecoverWithoutSymptoms = 
            this.getNormallyDistributedTime(
                meanTimeToBecomeSymptomaticOrRecoverWithoutSymptoms,
                stdTimeToBecomeSymptomaticOrRecoverWithoutSymptoms);
          this.willRecoverWithoutSymptoms = random(1.0) < chanceOfRecoveringWithoutSymtoms;
          this.canBeReinfected = random(1.0) < chanceOfLosingImmunity;
          this.willDie = random(1.0) < chanceOfPassing;
          break;
      
      case Symptomatic:
          this.healthColor = symptomatic;
          this.contagiousColor = contagious;
          this.timeBecameSymptomatic = millis();
          this.timeToBecomeRecoveredOrDie = this.getNormallyDistributedTime(
            meanTimeToBecomeRecoveredOrDeseased,
            stdTimeToBecomeRecoveredOrDeseased);          
          break;
      
      case RecoveredButContagious:
          this.healthColor = recovered;
          this.contagiousColor = contagious;
          this.timeBecameRecovered = millis();
          this.timeToBecomeTotallyRecovered = this.getNormallyDistributedTime(
            meanTimeToBecomeTotallyRecovered, stdTimeToBecomeTotallyRecovered);
          break;
      
      case RecoveredNotContagious:
          this.healthColor = recovered;
          this.contagiousColor = notContagious;
          this.timeBecameHealthy = millis();
          if (canBeReinfected) {
            this.timeToLoseImmunity = this.getNormallyDistributedTime(meanTimeToLoseImmunity, stdTimeToLoseImmunity);
          }
          break;
          
      case Deceased:
        this.healthColor = deceased;
        this.contagiousColor = deceased;
        break;
    }
    
    this.setColor(healthColor, contagiousColor);
    //println(id + " " + state);
  }
  
  public boolean checkForContact(Individual other)
  {
    float dist = sqrt(pow(this.xpos-other.xpos, 2) + pow(this.ypos-other.ypos, 2));    
    
    boolean madeContact = dist < radius*2;
    
    if (madeContact)
    {      
      float impactAngle = atan2(this.ypos-other.ypos, this.xpos-other.xpos);      
      float xd = cos(this.movementAngle);
      float yd = sin(this.movementAngle);
      float impactXd = cos(impactAngle);
      float impactYd = sin(impactAngle);     
      
      this.movementAngle = atan2(impactYd+yd, impactXd+xd);
      
      float impactAngleOther = atan2(other.ypos-this.ypos, other.xpos-this.xpos);
      float xdo = cos(other.movementAngle);
      float ydo = sin(other.movementAngle);
      float impactXdo = cos(impactAngleOther);
      float impactYdo = sin(impactAngleOther);      
      
      other.movementAngle = atan2(impactYdo+ydo, impactXdo+xdo);
      
      //stroke(deceased);
      //line(this.xpos, this.ypos, other.xpos, other.ypos);
      
      //println("Contact: " + this.id + "->" + other.id + ", d: " + dist);
      //println("id: " + id + ", x: " + xpos + ", y: " + ypos + ", ma: " + this.movementAngle + " imp: " +  atan2(other.ypos-this.ypos, other.xpos-this.xpos));
      //println("id: " + other.id + ", x: " + other.xpos + ", y: " + other.ypos + ", ma: " + other.movementAngle + " imp: " + atan2(this.ypos-other.ypos, this.xpos-other.xpos));
      //println(this.id + ", xd: " + xd + ", yd: " + yd + ", idx: " + impactXd + ", idy: ", impactYd);
      //println(other.id + ", xd: " + xdo + ", yd:" + ydo + ", idx: " + impactXdo + ", idy: ", impactYdo);
      //println();
      
      this.checkIfTransmit(this, other);
      this.checkIfTransmit(other, this);
      other = null;
    }
    
    return madeContact;
  }
  
  void checkIfTransmit(Individual a, Individual b)
  {
      if (a.isContagious() && !b.isContagious() && !b.isImmune() && random(1.0) < chanceOfCatching)
      {
          b.setHealth(HealthState.AsymptomaticButContagious);
      }
  }
  
  void update(boolean draw)
  {
       
    if (ypos-radius <= 0 || ypos+radius >= height) { 
      movementAngle = -movementAngle;
    }
    
    if (xpos-radius <= 0 || xpos+radius >= width) {
      movementAngle = PI - movementAngle;
    }
    
    // Don't move if symptomatic or deceased
    if (this.state == HealthState.Healthy ||
        this.state == HealthState.AsymptomaticButContagious ||
        this.state == HealthState.RecoveredButContagious ||
        this.state == HealthState.RecoveredNotContagious)
    {
      xpos += movementSpeed * cos(movementAngle);
      ypos += movementSpeed * sin(movementAngle);
    }
    
    long now = millis();
    if (this.state == HealthState.AsymptomaticButContagious)
    {
       if (now - timeBecameContagious > timeToBecomeSymptomaticOrRecoverWithoutSymptoms)
       {
         if (this.willRecoverWithoutSymptoms && !this.willDie)
         {
           this.setHealth(HealthState.RecoveredButContagious);           
         }
         else
         {
           this.setHealth(HealthState.Symptomatic);
         }
       }
    }
    else if (this.state == HealthState.Symptomatic)
    {
       if (now - timeBecameSymptomatic > timeToBecomeRecoveredOrDie)
       {
          if(this.willDie)
          {
            this.setHealth(HealthState.Deceased);
          }
          else
          {
            this.setHealth(HealthState.RecoveredButContagious);
          }
       }
    }
    else if (this.state == HealthState.RecoveredButContagious)
    {
       if (now - timeBecameRecovered > timeToBecomeTotallyRecovered)
       {
          this.setHealth(HealthState.RecoveredNotContagious);
       }  
    }
    else if (this.state == HealthState.RecoveredNotContagious)
    {
      if (this.canBeReinfected && now -  timeBecameHealthy > timeToLoseImmunity)
      {
         this.setHealth(HealthState.Healthy);
      }
    }
    
    if (draw)
    {
      stroke(this.contagiousColor);
      strokeWeight(3);
      fill(this.healthColor);
      circle(xpos, ypos, radius*2);
      //fill(0);
      //text(this.id,xpos,ypos+5);
    }
  }
}

public class PopulationHealthSlice
{
  LinkedHashMap<HealthState, Integer> map;
  int numContagious = 0;
  int populationSize = 0;
  
  PopulationHealthSlice(int populationSize) {
    this.map = new LinkedHashMap<HealthState, Integer>();
    
    this.map.put(HealthState.RecoveredNotContagious, 0);
    this.map.put(HealthState.RecoveredButContagious, 0);
    this.map.put(HealthState.Healthy, 0);
    this.map.put(HealthState.AsymptomaticButContagious, 0);
    this.map.put(HealthState.Symptomatic, 0);        
    this.map.put(HealthState.Deceased, 0);
    
    this.populationSize = populationSize;
  }
  
  public boolean simulationFinished()
  {
    return numContagious == 0;
  }
  
  public void update(Individual individual)
  {
    this.map.put(individual.state, this.map.get(individual.state)+1);   
    this.numContagious += individual.isContagious() ? 1 : 0;
  }
  
  public float percentAtHealth(HealthState hs)
  {
    return this.map.get(hs) / this.populationSize; 
  }
  
  public float percentShowingSymptoms()
  {
    return this.map.get(HealthState.Symptomatic) / this.populationSize;
  }
  
  public float percentContagious() {
    return this.numContagious / this.populationSize;
  }
  
  public void drawLine(int x, int y, int verticalPixels, int totalPop)
  {
    int yBottom = y;
    
    for (Map.Entry mapElement : map.entrySet())
    {
      HealthState hs = (HealthState)mapElement.getKey();
      int numInState = (int)mapElement.getValue();
      int yTop = yBottom + (int)((((float)numInState) / totalPop) * verticalPixels);
      if (yTop != yBottom)
      {
        stroke(colorMap.get(hs));
        line(x,yBottom,x,yTop);
      }
      //println(x,yBottom,yTop);
      yBottom = yTop;
    }
  }
}

void drawLegend()
{
  int x = 10;
  int y = populationSize + 20;
  int squareSize = 20;
  textAlign(LEFT, CENTER);
  for (HealthState state : HealthState.values()) { 
    fill(colorMap.get(state));
    stroke(colorMap.get(state));
    square(x, y, squareSize);
    text(state.toString(), x+squareSize+10, y+squareSize/2);
    y+= squareSize*2;
  }  
}
