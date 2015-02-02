import org.openkinect.*;
import org.openkinect.processing.*;
import processing.video.*;
import ddf.minim.*;

Kinect kinect; //kinect object

// Size of kinect image
int kW = 640;
int kH = 480;
float mapRatioX, mapRatioY; //ratio of screen size to kinect image

PImage depthImage; //source greyscale depth imagery

//calibration points and booleans
PVector tLeft, tRight, bLeft, bRight;
boolean calibrate, didMouseClick;
int calCorner;

PGraphics offscreen; //offscreen image
PImage calibImage; //calibrated greyscale depth image

Movie[] layerVids = new Movie[4]; //videos to be masked

PImage[] layerImages = new PImage[layerVids.length]; //copy of latest video frame
PImage[] masks = new PImage[layerVids.length]; //brightness-thresholded masks (B+W)
PImage[] maskImages = new PImage[layerVids.length]; //masked versions of layers
float[] layerPercents = new float[layerVids.length]; //percentage of layer currently showing

/*----Minim audio files-----*/
Minim minim;
AudioPlayer layerAudio1; //mars narration audio
AudioPlayer layerAudio3; //fracking narration audio

PVector[] thresholds = new PVector[4]; //array of thresholds for masking
//x = low threshold, y = high threshold

int modThreshold; //0-3: selects which threshold to modify with keypress
boolean rawImage; //show/hide raw depthImage (vs masked layer)
boolean debug;
int blur;

void setup()
{
  size(displayWidth, displayHeight, P2D);
  
  noCursor();
  noStroke();
  noSmooth();
  rectMode(CENTER);
  
  
  //load Kinect depth image
  kinect = new Kinect(this);
  kinect.start();
  kinect.enableDepth(true);
  
  //depthImage = loadImage("depthImage.jpg"); //sample image
  
  /*load layer images
  layerImages[0] = loadImage("layerImage1.jpg"); //load sample layer image 1
  layerImages[1] = loadImage("layerImage2.jpg"); //load sample layer image 2
  layerImages[2] = loadImage("layerImage3.jpg"); //load sample layer image 3
  layerImages[3] = loadImage("layerImage4.jpg"); //load sample layer image 4
  */
  
  //load layer videos
  layerVids[0] = new Movie(this, "layerVid1.mov");
  layerVids[1] = new Movie(this, "layerVid2.mov");
  layerVids[2] = new Movie(this, "layerVid3.mov");
  layerVids[3] = new Movie(this, "layerVid4.mov");
  
  //initialize layer videos(start looping), layer images, masks, mask images
  for (int i=0; i<layerVids.length; i++){
    layerVids[i].loop(); //start videos looping
    layerImages[i] = createImage(kW, kH, RGB); //create blank image with kinect dims
    masks[i] = createImage(kW, kH, RGB); //create blank image with kinect dims
    maskImages[i] = createImage(kW, kH, ARGB); //create blank image with kinect dims and alpha channel
  }
  
  //initialize minim audio layers
  minim = new Minim(this);
  layerAudio1 = minim.loadFile("layerAudio1.aif");
  layerAudio3 = minim.loadFile("layerAudio3.aif");
  layerAudio1.loop();
  layerAudio3.loop();
  
  //highest threshold = 162; //trial and error top of sandbox
  //lowest threshold = 152; //trial and error bottom of sandbox
  thresholds[0] = new PVector(161,255);
  thresholds[1] = new PVector(158,160);
  thresholds[2] = new PVector(155,157);
  thresholds[3] = new PVector(152,154);
  
  modThreshold = 0; //start with top layer
  rawImage = false; //start off showing the masked layer
  debug = false; //start without debug showing
  blur = 1;
  
  
  //-----KINECT PROJECTOR CALIBRATION-----//
  
  offscreen = createGraphics(kW, kH, P2D); //offscreen temp PGraphics for redrawing Kinect image
  calibImage = createImage(kW, kH, RGB); //the redrawn image

  tLeft = new PVector(0,0); //top left corner of cropped kinect image
  tRight = new PVector(kW, 0); //top right
  bRight = new PVector(kW, kH); //bottom right
  bLeft = new PVector(0, kH); //bottom left
  
  calibrate = true; //start with calibration
  didMouseClick = false; //mouse click for calibration
  calCorner = 0; //increment corner selection for calibration routine
  
  //get the ratio of the image to the screen size
  mapRatioX = float(width)/float(kW);
  mapRatioY = float(height)/float(kH);
  println("screen width = " + width + ", height = " + height);
  println("kinect image width = " + kW + ", height = " + kH);
  println("mapRatioX = " + mapRatioX + ", mapRatioY = " + mapRatioY);
  
}  
 
void draw()
{
  background(0);
  
  //get the latest depth image from the kinect
  depthImage = kinect.getDepthImage();
  
  calibImage = alignKinect(depthImage, offscreen, tLeft, tRight, bRight, bLeft);
    
  if (calibrate) { //start calibration routine
    calibrateKinect();
    
  } else if (rawImage) { //show raw depth image (no masked layer)
    image(calibImage,0,0,width,height);
    
  } else { //otherwise, calculate and display the masked layers
    
    //get layer images as last video frames and reset mask images
    for (int i=0;i<maskImages.length;i++){
      layerImages[i] = layerVids[i].get(); //get the newest frame from the video
      //and copy it to the mask image with the correct dims
      maskImages[i].copy(layerImages[i],0,0,layerImages[i].width,layerImages[i].height,0,0,kW,kH); 
    }
    
    //-----CREATE MASKED LAYER IMAGES-----//
    
    if (frameCount%2 == 0){ //HAPPENS EVERY 2nd DRAW
      //loop through masks
      for (int i=0; i < masks.length; i++) {
        makeMask(i); //make mask
      }
    }
    
    // apply the masks to maskImages
    for (int i=0; i<masks.length; i++){
      maskImages[i].mask(masks[i]);
    }
    
    //-----DRAW LAYERS FROM BOTTOM(3) TO TOP(0)-----//
    
    for (int i = maskImages.length-1; i >= 0; i--){
      
      //tint the videos like a topo map
      color c = color(255,255,255);
      switch(i){
        case 0:
          //c = color(230,99,4); //rust
          c = color(236,109,18);
          break;
        case 1:
          c = color(255,225,86);
          break;
        case 2:
          c = color(137,210,65);
          break;
        case 3:
          c = color(89,192,214);
          break;
        default:
          break;
      }
      tint(c);
      //draw the video
      image(maskImages[i], 0,0, width,height);
      noTint();
    }
    
    //-----SET VOLUMES-----//
    
    for (int i = 0; i < layerVids.length; i++){
        layerVids[i].volume(layerPercents[i]);
        
        //set minim audio volumes
        float gain = map(layerPercents[i], 0, 1, -13, 10);
        if (i == 0){ //mars
          layerAudio1.setGain(gain);
        } else if (i == 2){ //fracking
          layerAudio3.setGain(gain);
        }
    }

  }
  
  //draw debug info
  if (debug){
    pushStyle();
      rectMode(CORNER);
      textAlign(LEFT,TOP);
      fill(0,0,0);
      rect(70,70,300,300);
      fill(255,255,255);
      text("DEBUG",100,100);
      text("Processing fps: " + frameRate,100,120);
      for (int i=0; i<layerPercents.length; i++){
        text("layer " + i + " showing: " + nf(layerPercents[i], 3, 2) + "%", 100, 140+i*20);
      }
      text("mars volume: " + layerAudio1.getGain(), 100, 220);
      text("frack volume: " + layerAudio3.getGain(), 100, 240);
     popStyle();
  }
 
}

void makeMask(int maskNum){
  
    //load the pixels of the (calibrated) depth image to analyze them
    calibImage.loadPixels();

    //load the pixels of the mask to adjust
    masks[maskNum].loadPixels();
    
    //pixCount saves the number of pixels showing on the layer
    int pixCount = 0;
    
    //gauge brightness of depth image according to threshold
    //and make the mask with white and black values
    for (int x = 0; x < calibImage.width; x++ ) {
      for (int y = 0; y < calibImage.height; y++ ) {
        int loc = x + y*calibImage.width;
        
        // Test the brightness against the threshold
        if (brightness(calibImage.pixels[loc]) >= thresholds[maskNum].x && brightness(calibImage.pixels[loc]) <= thresholds[maskNum].y){
          masks[maskNum].pixels[loc] = color(255); // White (show)
          pixCount++; //increment pixCount counter
        } else {
          masks[maskNum].pixels[loc] = color(0);   // Black (don't show)
        }
      }
    }
    
    //convert pixCount to percentage
    layerPercents[maskNum] = float(pixCount)/float(calibImage.width*calibImage.height);
    
    //save the mask
    masks[maskNum].updatePixels();
    
    //close the depth image
    calibImage.updatePixels();
}


//calibration routine
void calibrateKinect(){
    
  //get mouseClicks at 4 corners
  color reddish = color(255,138,0);
  color bluey = color(0,255,216);
  
  //draw image w/ zeroed vertices
  fill(255,255,255);
  beginShape();
  texture(depthImage);
  vertex(0,0, 0,0);
  vertex(width,0, kW,0);
  vertex(width,height, kW,kH);
  vertex(0,height, 0,kH);
  endShape();
  
  //draw mouse circle
  fill(bluey); //turquoise circle
  ellipse(mouseX,mouseY,20,20);
  
  //map image vertices to onscreen coordinates
  PVector tLMap = new PVector(tLeft.x*mapRatioX, tLeft.y*mapRatioY);
  PVector tRMap = new PVector(tRight.x*mapRatioX, tRight.y*mapRatioY);
  PVector bRMap = new PVector(bRight.x*mapRatioX, bRight.y*mapRatioY);
  PVector bLMap = new PVector(bLeft.x*mapRatioX, bLeft.y*mapRatioY);
  
  //draw current corners
  fill(reddish);
  ellipse(tLMap.x,tLMap.y,10,10);
  fill(255,255,255);
  textAlign(LEFT,TOP);
  text("1",tLMap.x+10,tLMap.y+10);
  
  fill(reddish);
  ellipse(tRMap.x,tRMap.y,10,10);
  fill(255,255,255);
  textAlign(RIGHT,TOP);
  text("2",tRMap.x-10,tRMap.y+10);
  
  fill(reddish);
  ellipse(bRMap.x,bRMap.y,10,10);
  fill(255,255,255);
  textAlign(RIGHT,BOTTOM);
  text("3",bRMap.x-10,bRMap.y-10);
  
  fill(reddish);
  ellipse(bLMap.x,bLMap.y,10,10);
  fill(255,255,255);
  textAlign(LEFT,BOTTOM);
  text("4",bLMap.x+10,bLMap.y-10);
  
  //draw mouse dot
  fill(0,0,0); //black dot
  rect(mouseX,mouseY,1,1);
  //draw text showing calCorner
  fill(255,255,255);
  textAlign(LEFT,TOP);
  text(calCorner+1, mouseX+10, mouseY+10);

  //calibrate new corners on mouseClick
  if (didMouseClick) {
    switch (calCorner) {
      
      case 0: //corner 1
        tLeft.x = mouseX/mapRatioX;
        tLeft.y = mouseY/mapRatioY;
        calCorner++;
        break;
      
      case 1: //corner 2
        tRight.x = mouseX/mapRatioX;
        tRight.y = mouseY/mapRatioY;
        calCorner++;
        break;
      
      case 2: //corner 3
        bRight.x = mouseX/mapRatioX;
        bRight.y = mouseY/mapRatioY;
        calCorner++;
        break;
      
      case 3: //corner 4
        bLeft.x = mouseX/mapRatioX;
        bLeft.y = mouseY/mapRatioY;
        
        //reset switch
        calCorner=0;
        calibrate = false;
        break;
      }
    didMouseClick = false;
  }
}

//crop kinect image at the coordinates given using the PGraphics as temp space
PImage alignKinect(PImage kImg, PGraphics offScrn, PVector tL, PVector tR, PVector bR, PVector bL){
    
    //warp the depth image to calibration coordinates
    offScrn.beginDraw();
      offScrn.fill(255,255,255);
      offScrn.beginShape();
      offScrn.texture(kImg);
      //vertex(shape.x, shape.y, texture.x, texture.y);
      offScrn.vertex(0, 0, tL.x, tL.y);
      offScrn.vertex(kImg.width, 0, tR.x, tR.y);
      offScrn.vertex(kImg.width, kImg.height, bR.x, bR.y);
      offScrn.vertex(0, kImg.height, bL.x, bL.y);
      offScrn.endShape();
    offScrn.endDraw();
    
    return offScrn.get();
}




void keyPressed() {
  
  //modify currently selected threshold
  if (key == '-' || key == '=' || key == '[' || key == ']') {
    switch (key){
      case '-':
        if (thresholds[modThreshold].y > 0){
          thresholds[modThreshold].y--;
        }
        break;
      case '=':
        if (thresholds[modThreshold].y < 255){
          thresholds[modThreshold].y++;
        }
        break;
      case '[':
        if (thresholds[modThreshold].x > 0){
          thresholds[modThreshold].x--;
        }
        break;
      case ']':
        if (thresholds[modThreshold].x < 255){
          thresholds[modThreshold].x++;
        }
        break;
      default:
        break;
      } 
    println("new thresholds for layer " + (modThreshold+1) + " - lo: " + thresholds[modThreshold].x + ", hi: " + thresholds[modThreshold].y);
  } 
  //show raw depth image
  else if (key == 'r') {
      rawImage = !rawImage;
  } 
  //run calibration
  else if (key == 'c'){
      calibrate = !calibrate;
  } 
  //select threshold to modify
  else if (int(str(key)) > 0){
      int kInt = int(str(key));
      println("kInt = " + kInt);
      if(thresholds.length >= kInt){ //check to make sure threshold selector exists
        modThreshold = kInt - 1;
      }

    println("now modifying tresholds for layer " + (modThreshold+1) + " (current - lo: " + thresholds[modThreshold].x + ", hi: " + thresholds[modThreshold].y + ")");
  } 
  //print all current thresholds
  else if (key == 't'){

      println("Current thresholds:");
      for (int i=0; i<thresholds.length; i++){
        println("layer " + (i+1) + " lo: " + thresholds[i].x + ", hi: " + thresholds[i].y);
      }
  }
  //show debug info on screen
  else if (key =='d'){
    debug = !debug;
  }
  
  //decrease kinect image blur
  else if (key == 'v'){
    if (blur>0){
      blur--;
    }
    println("blur = " + blur);
  }
  //increase kinect image blur
  else if (key =='b'){
    blur++;
    println("blur = " + blur);
  }
  
}

void mouseClicked() {
  didMouseClick = true;
}


//makes sketch fullscreen
boolean sketchFullScreen() {
  return true;
}

void movieEvent(Movie m){
  m.read();
}
