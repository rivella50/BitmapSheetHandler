/**	
	BitmapSheetHandler

	Copyright (c) 2011 - Valentin Treu and contributors
	(see each file to see the different copyright owners)


	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:
	
	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.
		
	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
*/


package  {
	
	import com.adobe.serialization.json.JSONDecoder;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Loader;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	
	import spark.utils.MultiDPIBitmapSource;
	
	public class BitmapSheetHandler extends EventDispatcher {
		
		public static const DPI_160:int = 160;
		public static const DPI_240:int = 240;
		public static const DPI_320:int = 320;
		
		public static const DPI_SINGLE:int = 0;
				
		private var multiDPISheets:Object;
		private var multiDPIFrameData:Object;
		
		private var loadCounter:int;
		
		/**
		 * Constructor
		 */ 
		public function BitmapSheetHandler() {
			
			multiDPISheets    = new Object();
			multiDPIFrameData = new Object();
		}

		
		/**
		 * Load the sheets and its json files. Structure of config is:
		 * 	- dpi1 -> {'bitmapPath': BITMAP_PATH1, 'jsonPath': JSON_PATH1}
		 *  - dpi2 -> {'bitmapPath': BITMAP_PATH2, 'jsonPath': JSON_PATH2}
		 *  - ...
		 */ 
		public function importBitmapSheet(config:Object):void {
			
			loadCounter = 0;
			var sheetInfo:Object;
			var sheetLength:int = getConfigLength(config);
			
			for (var dpi:* in config) {
			
				sheetInfo = config[dpi];
				loadSheetData(dpi, sheetInfo, sheetLength);
			}	
		}
		
		/**
		 * Returns a Bitmap or MultiDPIBitmapSource (depending on multiDPI param) for the given image id.
		 */ 
		public function getImageSource(id:String, multiDPI:Boolean):Object {
			
			var result:Object;
			if (multiDPI == true) {
				
				var source:MultiDPIBitmapSource = new MultiDPIBitmapSource();
				var bitmap:Bitmap;
				if ((bitmap = getBitmapForId(id, DPI_160)) != null) { source.source160dpi = bitmap; }
				if ((bitmap = getBitmapForId(id, DPI_240)) != null) { source.source240dpi = bitmap; }
				if ((bitmap = getBitmapForId(id, DPI_320)) != null) { source.source320dpi = bitmap; }
				result = source;
				
			} else {
				
				result = getBitmapForId(id, DPI_SINGLE);
			}
			
			return result;
		}
		
		/**
		 * Loads the sheet image and the corresponding JSON config file for the given dpi value and the config paths.
		 * If this loading step is the last one to be imported a COMPLETE Event is dispatched as well.
		 */ 
		private function loadSheetData(dpi:*, sheetInfo:Object, length:int):void {
			
			var loader:Loader = new Loader();
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE, function(e:Event):void {
				
				var bitmapData:BitmapData = Bitmap(e.target.content).bitmapData;
				multiDPISheets[dpi] = bitmapData;
				
				var jsonLoader:URLLoader = new URLLoader();
				jsonLoader.addEventListener(Event.COMPLETE, function(f:Event):void {
					
					var jsonFile:JSONDecoder = new JSONDecoder(f.target.data, true);
					var frames:Object = jsonFile.getValue()['frames'];
					var id:String;
					var dict:Object = new Object();
					
					for (var fileName:String in frames){
						
						id = determineImageIdFromFilename(fileName);
						dict[id] = frames[fileName];
					}
					multiDPIFrameData[dpi] = dict;
					loadCounter++;
					if (loadCounter == length) {
						dispatchEvent(new Event(Event.COMPLETE));
					}
				});
				jsonLoader.load(new URLRequest(sheetInfo['jsonPath']));
			}
				
			);
			
			loader.load(new URLRequest(sheetInfo['bitmapPath']));
		}
		
		/**
		 * Determines an image id for the given image filename without any dimension info in it.
		 * Examples:
		 * 	- ball_48.png        -> ball
		 *  - soccer_ball_48.png -> soccer_ball
		 */ 
		private function determineImageIdFromFilename(filename:String):String {
			
			var id:String = null;
			var regexp:RegExp = /([a-zA-Z]+[[\D]+[a-zA-Z]+]*)[_\d{1,}]*.png/;
			var matches:Object = regexp.exec(filename);
			if (matches.length == 2) {
				id = matches[1];
			}
			return id;
		}
		
		/**
		 * Returns a new Bitmap for the given image id and dpi value if found in sheets and frame data.
		 */ 
		private function getBitmapForId(id:String, dpi:int):Bitmap {
			
			var bitmap:Bitmap = null;
			if (multiDPISheets[dpi] != null && multiDPIFrameData[dpi] != null && multiDPIFrameData[dpi][id] != null) {
				
				var sheet:BitmapData  = multiDPISheets[dpi];
				var frameData:Object = multiDPIFrameData[dpi][id];
				var object:Object = frameData["frame"];
				var width:int = object["w"];
				var height:int = object["h"];
				var x:int = object["x"];
				var y:int = object["y"];
				var canvas:BitmapData = new BitmapData(width, height);
				canvas.copyPixels(sheet, new Rectangle(x, y, width, height), new Point());
				bitmap = new Bitmap(canvas);
			}
			return bitmap;
		}
		
		/**
		 * Helper to determine the length of the different sheets to be imported in importBitmapSheet()
		 */ 
		private function getConfigLength(config:Object):int {
			var len:int = 0;
			for (var key:* in config) len++;
			return len;
		}
		
		
	}
}