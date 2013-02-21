/*
 *      _________  __      __
 *    _/        / / /____ / /________ ____ ____  ___
 *   _/        / / __/ -_) __/ __/ _ `/ _ `/ _ \/ _ \
 *  _/________/  \__/\__/\__/_/  \_,_/\_, /\___/_//_/
 *                                   /___/
 * 
 * Tetragon : Game Engine for multi-platform ActionScript projects.
 * http://www.tetragonengine.com/ - Copyright (C) 2012 Sascha Balkau
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
package view.pseudo3d
{
	import tetragon.data.texture.TextureAtlas;
	import tetragon.view.render2d.display.Image2D;
	import tetragon.view.render2d.display.View2D;
	import tetragon.view.render2d.events.Event2D;

	import view.pseudo3d.constants.COLORS;
	import view.pseudo3d.constants.ROAD;
	import view.pseudo3d.vo.Car;
	import view.pseudo3d.vo.PCamera;
	import view.pseudo3d.vo.PPoint;
	import view.pseudo3d.vo.PScreen;
	import view.pseudo3d.vo.PWorld;
	import view.pseudo3d.vo.SSprite;
	import view.pseudo3d.vo.Segment;
	import view.pseudo3d.vo.Sprites;
	
	
	/**
	 * @author hexagon
	 */
	public class Pseudo2DView extends View2D
	{
		//-----------------------------------------------------------------------------------------
		// Properties
		//-----------------------------------------------------------------------------------------
		
        private var _frameCount:int;
        private var _failCount:int;
        private var _waitFrames:int;
		
		private var fps:int = 60;							// how many 'update' frames per second
		private var step:Number = 1 / fps;					// how long is each frame (in seconds)
		private var centrifugal:Number = 0.3;				// centrifugal force multiplier when going around curves
		private var offRoadDecel:Number = 0.99;				// speed multiplier when off road (e.g. you lose 2% speed each update frame)
		
		private var skySpeed:Number = 0.001;				// background sky layer scroll speed when going around curve (or up hill)
		private var hillSpeed:Number = 0.002;				// background hill layer scroll speed when going around curve (or up hill)
		private var treeSpeed:Number = 0.003;				// background tree layer scroll speed when going around curve (or up hill)
		
		private var skyOffset:int = 0;						// current sky scroll offset
		private var hillOffset:int = 0;						// current hill scroll offset
		private var treeOffset:int = 0;						// current tree scroll offset
		
		private var segments:Vector.<Segment>;				// array of road segments
		private var cars:Vector.<Car>;						// array of cars on the road
		
		private var ctx:RenderBuffer;
		private var bufferWidth:int;
		private var bufferHeight:int;
		private var image:Image2D;
		private var atlas:TextureAtlas;
		private var resolution:Number;						// scaling factor to provide resolution independence (computed)
		
		private var roadWidth:int = 2000;					// actually half the roads width, easier math if the road spans from -roadWidth to +roadWidth
		private var segmentLength:int = 200;				// length of a single segment
		private var rumbleLength:int = 3;					// number of segments per red/white rumble strip
		private var trackLength:int;						// z length of entire track (computed)
		private var lanes:int = 3;							// number of lanes
		private var fieldOfView:int = 100;					// angle (degrees) for field of view
		private var cameraHeight:int = 1000;				// z height of camera
		private var cameraDepth:int;						// z distance camera is from screen (computed)
		private var drawDistance:int = 300;					// number of segments to draw
		private var playerX:Number = 0;						// player x offset from center of road (-1 to 1 to stay independent of roadWidth)
		private var playerZ:Number;							// player relative z distance from camera (computed)
		private var fogDensity:int = 5;						// exponential fog density
		private var position:Number = 0;					// current camera Z position (add playerZ to get player's absolute Z position)
		private var speed:Number = 0;						// current speed
		private var maxSpeed:Number = segmentLength / step;	// top speed (ensure we can't move more than 1 segment in a single frame to make collision detection easier)
		private var accel:Number = maxSpeed / 5;			// acceleration rate - tuned until it 'felt' right
		private var breaking:Number = -maxSpeed;			// deceleration rate when braking
		private var decel:Number = -maxSpeed / 5;			// 'natural' deceleration rate when neither accelerating, nor braking
		private var offRoadLimit:Number = maxSpeed / 4;		// limit when off road deceleration no longer applies (e.g. you can always go at least this speed even when off road)
		private var totalCars:Number = 200;					// total number of cars on the road
		private var currentLapTime:Number = 0;				// current lap time
		private var lastLapTime:Number;						// last lap time
		
		private var SPRITES:Sprites;
		
		private var keyLeft:Boolean;
		private var keyRight:Boolean;
		private var keyFaster:Boolean;
		private var keySlower:Boolean;
		
		
		//-----------------------------------------------------------------------------------------
		// Constructor
		//-----------------------------------------------------------------------------------------
		
		/**
		 * Creates a new instance of the class.
		 */
		public function Pseudo2DView()
		{
		}
		
		
		//-----------------------------------------------------------------------------------------
		// Public Methods
		//-----------------------------------------------------------------------------------------
		
		/**
		 * @private
		 */
		public function start():void
		{
			bufferWidth = 640;
			bufferHeight = 480;
			ctx = new RenderBuffer(bufferWidth, bufferHeight);
			image = new Image2D(ctx);
			addChild(image);
			
			prepareSprites();
			
			// off road deceleration is somewhere in between
			offRoadDecel = -maxSpeed / 2;
			
			cameraDepth = 1 / Math.tan((fieldOfView / 2) * Math.PI / 180);
			playerZ = (cameraHeight * cameraDepth);
			resolution = bufferHeight / 640;
			
			resetRoad();
		}
		
		
		/**
		 * @private
		 */
		private function prepareSprites():void
		{
			atlas = _main.resourceManager.resourceIndex.getResourceContent("spriteTextureAtlas");
			SPRITES = new Sprites();
			
			SPRITES.BG_SKY = new Image2D(atlas.getTexture("bg_sky"));
			SPRITES.BG_HILLS = new Image2D(atlas.getTexture("bg_hills"));
			SPRITES.BG_TREES = new Image2D(atlas.getTexture("bg_trees"));
			
			SPRITES.BILLBOARD01 = new Image2D(atlas.getTexture("sprite_billboard01"));
			SPRITES.BILLBOARD02 = new Image2D(atlas.getTexture("sprite_billboard02"));
			SPRITES.BILLBOARD03 = new Image2D(atlas.getTexture("sprite_billboard03"));
			SPRITES.BILLBOARD04 = new Image2D(atlas.getTexture("sprite_billboard04"));
			SPRITES.BILLBOARD05 = new Image2D(atlas.getTexture("sprite_billboard05"));
			SPRITES.BILLBOARD06 = new Image2D(atlas.getTexture("sprite_billboard06"));
			SPRITES.BILLBOARD07 = new Image2D(atlas.getTexture("sprite_billboard07"));
			SPRITES.BILLBOARD08 = new Image2D(atlas.getTexture("sprite_billboard08"));
			SPRITES.BILLBOARD09 = new Image2D(atlas.getTexture("sprite_billboard09"));
			
			SPRITES.BOULDER1 = new Image2D(atlas.getTexture("sprite_boulder1"));
			SPRITES.BOULDER2 = new Image2D(atlas.getTexture("sprite_boulder2"));
			SPRITES.BOULDER3 = new Image2D(atlas.getTexture("sprite_boulder3"));
			
			SPRITES.BUSH1 = new Image2D(atlas.getTexture("sprite_bush1"));
			SPRITES.BUSH2 = new Image2D(atlas.getTexture("sprite_bush2"));
			SPRITES.CACTUS = new Image2D(atlas.getTexture("sprite_cactus"));
			SPRITES.TREE1 = new Image2D(atlas.getTexture("sprite_tree1"));
			SPRITES.TREE2 = new Image2D(atlas.getTexture("sprite_tree2"));
			SPRITES.PALM_TREE = new Image2D(atlas.getTexture("sprite_palm_tree"));
			SPRITES.DEAD_TREE1 = new Image2D(atlas.getTexture("sprite_dead_tree1"));
			SPRITES.DEAD_TREE2 = new Image2D(atlas.getTexture("sprite_dead_tree2"));
			SPRITES.STUMP = new Image2D(atlas.getTexture("sprite_stump"));
			SPRITES.COLUMN = new Image2D(atlas.getTexture("sprite_column"));
			
			SPRITES.CAR01 = new Image2D(atlas.getTexture("sprite_car01"));
			SPRITES.CAR02 = new Image2D(atlas.getTexture("sprite_car02"));
			SPRITES.CAR03 = new Image2D(atlas.getTexture("sprite_car03"));
			SPRITES.CAR04 = new Image2D(atlas.getTexture("sprite_car04"));
			SPRITES.SEMI = new Image2D(atlas.getTexture("sprite_semi"));
			SPRITES.TRUCK = new Image2D(atlas.getTexture("sprite_truck"));
			
			SPRITES.PLAYER_STRAIGHT = new Image2D(atlas.getTexture("sprite_player_straight"));
			SPRITES.PLAYER_LEFT = new Image2D(atlas.getTexture("sprite_player_left"));
			SPRITES.PLAYER_RIGHT = new Image2D(atlas.getTexture("sprite_player_right"));
			SPRITES.PLAYER_UPHILL_STRAIGHT = new Image2D(atlas.getTexture("sprite_player_uphill_straight"));
			SPRITES.PLAYER_UPHILL_LEFT = new Image2D(atlas.getTexture("sprite_player_uphill_left"));
			SPRITES.PLAYER_UPHILL_RIGHT = new Image2D(atlas.getTexture("sprite_player_uphill_right"));
			
			SPRITES.init();
		}
		
		
		// =========================================================================
		// BUILD ROAD GEOMETRY
		// =========================================================================
		
		private function resetRoad():void
		{
			segments = new Vector.<Segment>();
			
			addStraight(ROAD.LENGTH.SHORT);
			addLowRollingHills();
			addSCurves();
			addCurve(ROAD.LENGTH.MEDIUM, ROAD.CURVE.MEDIUM, ROAD.HILL.LOW);
			addBumps();
			addLowRollingHills();
			addCurve(ROAD.LENGTH.LONG * 2, ROAD.CURVE.MEDIUM, ROAD.HILL.MEDIUM);
			addStraight();
			addHill(ROAD.LENGTH.MEDIUM, ROAD.HILL.HIGH);
			addSCurves();
			addCurve(ROAD.LENGTH.LONG, -ROAD.CURVE.MEDIUM, ROAD.HILL.NONE);
			addHill(ROAD.LENGTH.LONG, ROAD.HILL.HIGH);
			addCurve(ROAD.LENGTH.LONG, ROAD.CURVE.MEDIUM, -ROAD.HILL.LOW);
			addBumps();
			addHill(ROAD.LENGTH.LONG, -ROAD.HILL.MEDIUM);
			addStraight();
			addSCurves();
			addDownhillToEnd();
			
			resetSprites();
			resetCars();
			
			segments[findSegment(playerZ).index + 2].color = COLORS.START;
			segments[findSegment(playerZ).index + 3].color = COLORS.START;
			
			for (var n:int = 0; n < rumbleLength; n++)
			{
				segments[segments.length - 1 - n].color = COLORS.FINISH;
			}

			trackLength = segments.length * segmentLength;
		}
		
		
		private function resetSprites():void
		{
			var n:int, i:int;
			var side:Number, sprite:Image2D, offset:Number;

			addSprite(20, SPRITES.BILLBOARD07, -1);
			addSprite(40, SPRITES.BILLBOARD06, -1);
			addSprite(60, SPRITES.BILLBOARD08, -1);
			addSprite(80, SPRITES.BILLBOARD09, -1);
			addSprite(100, SPRITES.BILLBOARD01, -1);
			addSprite(120, SPRITES.BILLBOARD02, -1);
			addSprite(140, SPRITES.BILLBOARD03, -1);
			addSprite(160, SPRITES.BILLBOARD04, -1);
			addSprite(180, SPRITES.BILLBOARD05, -1);

			addSprite(240, SPRITES.BILLBOARD07, -1.2);
			addSprite(240, SPRITES.BILLBOARD06, 1.2);
			addSprite(segments.length - 25, SPRITES.BILLBOARD07, -1.2);
			addSprite(segments.length - 25, SPRITES.BILLBOARD06, 1.2);
			
			for (n = 10; n < 200; n += 4 + Math.floor(n / 100))
			{
				addSprite(n, SPRITES.PALM_TREE, 0.5 + Math.random() * 0.5);
				addSprite(n, SPRITES.PALM_TREE, 1 + Math.random() * 2);
			}
			
			for (n = 250; n < 1000; n += 5)
			{
				addSprite(n, SPRITES.COLUMN, 1.1);
				addSprite(n + Util.randomInt(0, 5), SPRITES.TREE1, -1 - (Math.random() * 2));
				addSprite(n + Util.randomInt(0, 5), SPRITES.TREE2, -1 - (Math.random() * 2));
			}
			
			for (n = 200; n < segments.length; n += 3)
			{
				addSprite(n, Util.randomChoice(SPRITES.PLANTS), Util.randomChoice([1, -1]) * (2 + Math.random() * 5));
			}
			
			for (n = 1000; n < (segments.length - 50); n += 100)
			{
				side = Util.randomChoice([1, -1]);
				addSprite(n + Util.randomInt(0, 50), Util.randomChoice(SPRITES.BILLBOARDS), -side);
				for (i = 0 ; i < 20 ; i++)
				{
					sprite = Util.randomChoice(SPRITES.PLANTS);
					offset = side * (1.5 + Math.random());
					addSprite(n + Util.randomInt(0, 50), sprite, offset);
				}
			}
		}
		
		
		private function resetCars():void
		{
			cars = new Vector.<Car>();
			var n:int, car:Car, segment:Segment, offset:Number, z:Number, sprite:Image2D, speed:Number;
			
			for (n = 0; n < totalCars; n++)
			{
				offset = Math.random() * Util.randomChoice([-0.8, 0.8]);
				z = Math.floor(Math.random() * segments.length) * segmentLength;
				sprite = Util.randomChoice(SPRITES.CARS);
				speed = maxSpeed / 4 + Math.random() * maxSpeed / (sprite == SPRITES.SEMI ? 4 : 2);
				car = new Car(offset, z, new SSprite(sprite), speed);
				segment = findSegment(car.z);
				segment.cars.push(car);
				cars.push(car);
			}
		}
		
		
		private function lastY():Number
		{
			return (segments.length == 0) ? 0 : segments[segments.length - 1].p2.world.y;
		}
		
		
		private function findSegment(z:Number):Segment
		{
			return segments[Math.floor(z / segmentLength) % segments.length];
		}
		
		
		private function addSegment(curve:Number, y:Number):void
		{
			var n:uint = segments.length;
			var seg:Segment = new Segment();
			seg.index = n;
			seg.p1 = new PPoint(new PWorld(lastY(), n * segmentLength), new PCamera(), new PScreen());
			seg.p2 = new PPoint(new PWorld(y, (n + 1) * segmentLength), new PCamera(), new PScreen());
			seg.curve = curve;
			seg.sprites = new Vector.<SSprite>();
			seg.cars = new Vector.<Car>();
			seg.color = Math.floor(n / rumbleLength) % 2 ? COLORS.DARK : COLORS.LIGHT;
			segments.push(seg);
		}
		
		
		private function addSprite(n:int, sprite:Image2D, offset:Number):void
		{
			var s:SSprite = new SSprite(sprite, offset);
			segments[n].sprites.push(s);
		}
		
		
		private function addRoad(enter:int, hold:int, leave:int, curve:Number, y:Number):void
		{
			var startY:Number = lastY();
			var endY:Number = startY + (Util.toInt(y, 0) * segmentLength);
			var n:int, total:int = enter + hold + leave;
			
			for (n = 0 ; n < enter; n++)
			{
				addSegment(Util.easeIn(0, curve, n / enter), Util.easeInOut(startY, endY, n / total));
			}
			for (n = 0 ; n < hold; n++)
			{
				addSegment(curve, Util.easeInOut(startY, endY, (enter + n) / total));
			}
			for (n = 0 ; n < leave; n++)
			{
				addSegment(Util.easeInOut(curve, 0, n / leave), Util.easeInOut(startY, endY, (enter + hold + n) / total));
			}
		}
		
		
		private function addStraight(num:int = ROAD.LENGTH.MEDIUM):void
		{
			addRoad(num, num, num, 0, 0);
		}
		
		
		private function addHill(num:int = ROAD.LENGTH.MEDIUM, height:int = ROAD.HILL.MEDIUM):void
		{
			addRoad(num, num, num, 0, height);
		}
		
		
		private function addCurve(num:int = ROAD.LENGTH.MEDIUM, curve:int = ROAD.CURVE.MEDIUM,
			height:int = ROAD.HILL.NONE):void
		{
			addRoad(num, num, num, curve, height);
		}
		
		
		private function addLowRollingHills(num:int = ROAD.LENGTH.SHORT,
			height:int = ROAD.HILL.LOW):void
		{
			addRoad(num, num, num, 0, height / 2);
			addRoad(num, num, num, 0, -height);
			addRoad(num, num, num, ROAD.CURVE.EASY, height);
			addRoad(num, num, num, 0, 0);
			addRoad(num, num, num, -ROAD.CURVE.EASY, height / 2);
			addRoad(num, num, num, 0, 0);
		}
		
		
		private function addSCurves():void
		{
			addRoad(ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, -ROAD.CURVE.EASY, ROAD.HILL.NONE);
			addRoad(ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.CURVE.MEDIUM, ROAD.HILL.MEDIUM);
			addRoad(ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.CURVE.EASY, -ROAD.HILL.LOW);
			addRoad(ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, -ROAD.CURVE.EASY, ROAD.HILL.MEDIUM);
			addRoad(ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, -ROAD.CURVE.MEDIUM, -ROAD.HILL.MEDIUM);
		}


		private function addBumps():void
		{
			addRoad(10, 10, 10, 0, 5);
			addRoad(10, 10, 10, 0, -2);
			addRoad(10, 10, 10, 0, -5);
			addRoad(10, 10, 10, 0, 8);
			addRoad(10, 10, 10, 0, 5);
			addRoad(10, 10, 10, 0, -7);
			addRoad(10, 10, 10, 0, 5);
			addRoad(10, 10, 10, 0, -2);
		}


		private function addDownhillToEnd(num:int = 200):void
		{
			addRoad(num, num, num, -ROAD.CURVE.EASY, -lastY() / segmentLength);
		}
		
		
		//-----------------------------------------------------------------------------------------
		// Accessors
		//-----------------------------------------------------------------------------------------
		
		
		//-----------------------------------------------------------------------------------------
		// Callback Handlers
		//-----------------------------------------------------------------------------------------
		
		override protected function onAddedToStage(e:Event2D):void
		{
			super.onAddedToStage(e);
				
			_failCount = 0;
			_waitFrames = 2;
			_frameCount = 0;
			
			_gameLoop.tickSignal.add(onTick);
			_gameLoop.renderSignal.add(onRender);
		}


		private function onTick():void
		{
			update(step);
		}
		
		
		override protected function onRender(ticks:uint, ms:uint, fps:uint):void
		{
			renderGame();
		}
		
		
		//-----------------------------------------------------------------------------------------
		// Private Methods
		//-----------------------------------------------------------------------------------------
		
		override protected function setup():void
		{
			super.setup();
		}
		
		
		private function update(dt:Number):void
		{
			var n:int, car:Car, carW:Number, sprite:SSprite, spriteW:Number;
			var playerSegment:Segment = findSegment(position + playerZ);
			var playerW:Number = SPRITES.PLAYER_STRAIGHT.width * SPRITES.SCALE;
			var speedPercent:Number = speed / maxSpeed;
			
			// at top speed, should be able to cross from left to right (-1 to 1) in 1 second
			var dx:Number = dt * 2 * speedPercent;
			
			var startPosition:Number = position;

			updateCars(dt, playerSegment, playerW);

			position = Util.increase(position, dt * speed, trackLength);

			if (keyLeft) playerX = playerX - dx;
			else if (keyRight) playerX = playerX + dx;
			
			playerX = playerX - (dx * speedPercent * playerSegment.curve * centrifugal);
			
			if (keyFaster) speed = Util.accelerate(speed, accel, dt);
			else if (keySlower) speed = Util.accelerate(speed, breaking, dt);
			else speed = Util.accelerate(speed, decel, dt);
			
			if ((playerX < -1) || (playerX > 1))
			{
				if (speed > offRoadLimit) speed = Util.accelerate(speed, offRoadDecel, dt);
				
				for (n = 0; n < playerSegment.sprites.length; n++)
				{
					sprite = playerSegment.sprites[n];
					spriteW = sprite.source.width * SPRITES.SCALE;
					if (Util.overlap(playerX, playerW, sprite.offset + spriteW / 2 * (sprite.offset > 0 ? 1 : -1), spriteW))
					{
						speed = maxSpeed / 5;
						// stop in front of sprite (at front of segment)
						position = Util.increase(playerSegment.p1.world.z, -playerZ, trackLength);
						break;
					}
				}
			}
			
			for (n = 0; n < playerSegment.cars.length; n++)
			{
				car = playerSegment.cars[n];
				carW = car.sprite.source.width * SPRITES.SCALE;
				if (speed > car.speed)
				{
					if (Util.overlap(playerX, playerW, car.offset, carW, 0.8))
					{
						speed = car.speed * (car.speed / speed);
						position = Util.increase(car.z, -playerZ, trackLength);
						break;
					}
				}
			}
			
			// dont ever let it go too far out of bounds
			playerX = Util.limit(playerX, -3, 3);
			// or exceed maxSpeed
			speed = Util.limit(speed, 0, maxSpeed);
			
			skyOffset = Util.increase(skyOffset, skySpeed * playerSegment.curve * (position - startPosition) / segmentLength, 1);
			hillOffset = Util.increase(hillOffset, hillSpeed * playerSegment.curve * (position - startPosition) / segmentLength, 1);
			treeOffset = Util.increase(treeOffset, treeSpeed * playerSegment.curve * (position - startPosition) / segmentLength, 1);
			
			if (position > playerZ)
			{
				if (currentLapTime && (startPosition < playerZ))
				{
					lastLapTime = currentLapTime;
					currentLapTime = 0;
					//if (lastLapTime <= Util.toFloat(Dom.storage.fast_lap_time))
					//{
					//	Dom.storage.fast_lap_time = lastLapTime;
					//	updateHud('fast_lap_time', formatTime(lastLapTime));
					//	Dom.addClassName('fast_lap_time', 'fastest');
					//	Dom.addClassName('last_lap_time', 'fastest');
					//}
					//else
					//{
					//	Dom.removeClassName('fast_lap_time', 'fastest');
					//	Dom.removeClassName('last_lap_time', 'fastest');
					//}
					updateHUD('last_lap_time', formatTime(lastLapTime));
					//Dom.show('last_lap_time');
				}
				else
				{
					currentLapTime += dt;
				}
			}

			updateHUD('speed', "" + (5 * Math.round(speed / 500)));
			updateHUD('current_lap_time', formatTime(currentLapTime));
		}
		
		
		private function updateCars(dt:Number, playerSegment:Segment, playerW:Number):void
		{
			var n:int, car:Car, oldSegment:Segment, newSegment:Segment;
			for (n = 0 ; n < cars.length ; n++)
			{
				car = cars[n];
				oldSegment = findSegment(car.z);
				car.offset = car.offset + updateCarOffset(car, oldSegment, playerSegment, playerW);
				car.z = Util.increase(car.z, dt * car.speed, trackLength);
				car.percent = Util.percentRemaining(car.z, segmentLength);
				// useful for interpolation during rendering phase
				newSegment = findSegment(car.z);
				if (oldSegment != newSegment)
				{
					var index:int = oldSegment.cars.indexOf(car);
					oldSegment.cars.splice(index, 1);
					newSegment.cars.push(car);
				}
			}
		}


		private function updateCarOffset(car:Car, carSegment:Segment, playerSegment:Segment, playerW:Number):Number
		{
			var i:int, j:int, dir:Number, segment:Segment, otherCar:Car, otherCarW:Number,
			lookahead:int = 20, carW:Number = car.sprite.source.width * SPRITES.SCALE;

			// optimization, dont bother steering around other cars when 'out of sight' of the player
			if ((carSegment.index - playerSegment.index) > drawDistance)
				return 0;

			for (i = 1 ; i < lookahead ; i++)
			{
				segment = segments[(carSegment.index + i) % segments.length];

				if ((segment === playerSegment) && (car.speed > speed) && (Util.overlap(playerX, playerW, car.offset, carW, 1.2)))
				{
					if (playerX > 0.5)
						dir = -1;
					else if (playerX < -0.5)
						dir = 1;
					else
						dir = (car.offset > playerX) ? 1 : -1;
					return dir * 1 / i * (car.speed - speed) / maxSpeed;
					// the closer the cars (smaller i) and the greated the speed ratio, the larger the offset
				}

				for (j = 0 ; j < segment.cars.length ; j++)
				{
					otherCar = segment.cars[j];
					otherCarW = otherCar.sprite.source.width * SPRITES.SCALE;
					if ((car.speed > otherCar.speed) && Util.overlap(car.offset, carW, otherCar.offset, otherCarW, 1.2))
					{
						if (otherCar.offset > 0.5)
							dir = -1;
						else if (otherCar.offset < -0.5)
							dir = 1;
						else
							dir = (car.offset > otherCar.offset) ? 1 : -1;
						return dir * 1 / i * (car.speed - otherCar.speed) / maxSpeed;
					}
				}
			}

			// if no cars ahead, but I have somehow ended up off road, then steer back on
			if (car.offset < -0.9) return 0.1;
			else if (car.offset > 0.9) return -0.1;
			else return 0;
		}
		
		
		private function renderGame():void
		{
			var baseSegment:Segment = findSegment(position);
			var basePercent:Number = Util.percentRemaining(position, segmentLength);
			var playerSegment:Segment = findSegment(position + playerZ);
			var playerPercent:Number = Util.percentRemaining(position + playerZ, segmentLength);
			var playerY:Number = Util.interpolate(playerSegment.p1.world.y, playerSegment.p2.world.y, playerPercent);
			var maxy:Number = bufferHeight;
			
			var x:Number = 0;
			var dx:Number = - (baseSegment.curve * basePercent);
			
			var n:int, i:int, segment:Segment, car:Car, sprite:SSprite, spriteScale:Number,
				spriteX:Number, spriteY:Number;
			
			ctx.clear();
			
			/* Render the background. */
			Render.background(ctx, atlas, bufferWidth, bufferHeight, SPRITES.BG_SKY, skyOffset, resolution * skySpeed * playerY);
			Render.background(ctx, atlas, bufferWidth, bufferHeight, SPRITES.BG_HILLS, hillOffset, resolution * hillSpeed * playerY);
			Render.background(ctx, atlas, bufferWidth, bufferHeight, SPRITES.BG_TREES, treeOffset, resolution * treeSpeed * playerY);
			
			/* PHASE 1: render segments, front to back and clip far segments that have been
			 * obscured by already rendered near segments if their projected coordinates are
			 * lower than maxy. */
			for (n = 0; n < drawDistance; n++)
			{
				segment = segments[(baseSegment.index + n) % segments.length];
				segment.looped = segment.index < baseSegment.index;
				segment.fog = Util.exponentialFog(n / drawDistance, fogDensity);
				segment.clip = maxy;
				
				Util.project(segment.p1, (playerX * roadWidth) - x, playerY + cameraHeight,
					position - (segment.looped ? trackLength : 0), cameraDepth, bufferWidth, bufferHeight, roadWidth);
				Util.project(segment.p2, (playerX * roadWidth) - x - dx, playerY + cameraHeight,
					position - (segment.looped ? trackLength : 0), cameraDepth, bufferWidth, bufferHeight, roadWidth);
				
				x = x + dx;
				dx = dx + segment.curve;
				
				if ((segment.p1.camera.z <= cameraDepth)				// behind us
					|| (segment.p2.screen.y >= segment.p1.screen.y)		// back face cull
					|| (segment.p2.screen.y >= maxy))					// clip by (already rendered) hill
				{
					continue;
				}
				
				Render.segment(ctx, bufferWidth, lanes, segment.p1.screen.x, segment.p1.screen.y, segment.p1.screen.w, segment.p2.screen.x, segment.p2.screen.y, segment.p2.screen.w, segment.fog, segment.color);
				maxy = segment.p1.screen.y;
			}
			
			/* PHASE 2: Back to front render the sprites. */
			for (n = (drawDistance - 1); n > 0; n--)
			{
				segment = segments[(baseSegment.index + n) % segments.length];
				
				/* Render oponents. */
				for (i = 0; i < segment.cars.length; i++)
				{
					car = segment.cars[i];
					sprite = car.sprite;
					spriteScale = Util.interpolate(segment.p1.screen.scale, segment.p2.screen.scale, car.percent);
					spriteX = Util.interpolate(segment.p1.screen.x, segment.p2.screen.x, car.percent) + (spriteScale * car.offset * roadWidth * bufferWidth / 2);
					spriteY = Util.interpolate(segment.p1.screen.y, segment.p2.screen.y, car.percent);
					Render.sprite(ctx, bufferWidth, bufferHeight, resolution, roadWidth, atlas, car.sprite.source, SPRITES, spriteScale, spriteX, spriteY, -0.5, -1, segment.clip);
				}
				
				/* Render decoration and obstacle sprites. */
				for (i = 0; i < segment.sprites.length; i++)
				{
					sprite = segment.sprites[i];
					spriteScale = segment.p1.screen.scale;
					spriteX = segment.p1.screen.x + (spriteScale * sprite.offset * roadWidth * bufferWidth / 2);
					spriteY = segment.p1.screen.y;
					Render.sprite(ctx, bufferWidth, bufferHeight, resolution, roadWidth, atlas, sprite.source, SPRITES, spriteScale, spriteX, spriteY, (sprite.offset < 0 ? -1 : 0), -1, segment.clip);
				}
				
				/* Render player sprite. */
				if (segment == playerSegment)
				{
					Render.player(ctx, bufferWidth, bufferHeight, resolution, roadWidth, atlas, SPRITES, speed / maxSpeed,
						cameraDepth / playerZ, bufferWidth / 2,
						(bufferHeight / 2) - (cameraDepth / playerZ * Util.interpolate(playerSegment.p1.camera.y, playerSegment.p2.camera.y, playerPercent) * bufferHeight / 2), speed * (keyLeft ? -1 : keyRight ? 1 : 0), playerSegment.p2.world.y - playerSegment.p1.world.y);
				}
			}
		}
		
		
		private function updateHUD(key:String, value:String):void
		{
			// accessing DOM can be slow, so only do it if value has changed
			//if (hud[key].value !== value)
			//{
			//	hud[key].value = value;
			//	Dom.set(hud[key].dom, value);
			//}
		}


		private function formatTime(dt:Number):String
		{
			var minutes:Number = Math.floor(dt / 60);
			var seconds:Number = Math.floor(dt - (minutes * 60));
			var tenths:Number = Math.floor(10 * (dt - Math.floor(dt)));
			if (minutes > 0) return minutes + "." + (seconds < 10 ? "0" : "") + seconds + "." + tenths;
			else return seconds + "." + tenths;
		}
	}
}
