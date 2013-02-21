package view.pseudo3d
{
	import tetragon.data.texture.TextureAtlas;
	import tetragon.view.render2d.display.Image2D;

	import view.pseudo3d.constants.COLORS;
	import view.pseudo3d.constants.ColorSet;
	import view.pseudo3d.vo.Sprites;
	
	
	/**
	 * Render
	 * @author Hexagon
	 */
	public class Render
	{
		public static function polygon(ctx:RenderBuffer, x1:Number, y1:Number, x2:Number, y2:Number, x3:Number,
			y3:Number, x4:Number, y4:Number, color:uint):void
		{
			ctx.fillStyle = color;
			ctx.beginPath();
			ctx.moveTo(x1, y1);
			ctx.lineTo(x2, y2);
			ctx.lineTo(x3, y3);
			ctx.lineTo(x4, y4);
			ctx.closePath();
			ctx.fill();
		}
		
		
		public static function segment(ctx:RenderBuffer, width:Number, lanes:int, x1:Number, y1:Number,
			w1:Number, x2:Number, y2:Number, w2:Number, fogNum:Number, color:ColorSet):void
		{
			var r1:Number = rumbleWidth(w1, lanes),
				r2:Number = rumbleWidth(w2, lanes),
				l1:Number = laneMarkerWidth(w1, lanes),
				l2:Number = laneMarkerWidth(w2, lanes),
				lanew1:Number, lanew2:Number, lanex1:Number, lanex2:Number, lane:int;
			
			ctx.fillStyle = color.grass;
			ctx.fillRect(0, y2, width, y1 - y2);

			polygon(ctx, x1 - w1 - r1, y1, x1 - w1, y1, x2 - w2, y2, x2 - w2 - r2, y2, color.rumble);
			polygon(ctx, x1 + w1 + r1, y1, x1 + w1, y1, x2 + w2, y2, x2 + w2 + r2, y2, color.rumble);
			polygon(ctx, x1 - w1, y1, x1 + w1, y1, x2 + w2, y2, x2 - w2, y2, color.road);
			
			if (color.lane)
			{
				lanew1 = w1 * 2 / lanes;
				lanew2 = w2 * 2 / lanes;
				lanex1 = x1 - w1 + lanew1;
				lanex2 = x2 - w2 + lanew2;
				for (lane = 1 ; lane < lanes ; lanex1 += lanew1, lanex2 += lanew2, lane++)
				{
					polygon(ctx, lanex1 - l1 / 2, y1, lanex1 + l1 / 2, y1, lanex2 + l2 / 2, y2, lanex2 - l2 / 2, y2, color.lane);
				}
			}
			
			fog(ctx, 0, y1, width, y2 - y1, fogNum);
		}
		
		
		public static function background(ctx:RenderBuffer, atlas:TextureAtlas, width:Number,
			height:Number, layer:Image2D, rotation:Number = 0.0, offset:Number = 0.0):void
		{
			var imageW:Number = layer.width / 2;
			var imageH:Number = layer.height;
			var sourceX:Number = layer.x + Math.floor(layer.width * rotation);
			var sourceY:Number = layer.y;
			var sourceW:Number = Math.min(imageW, layer.x + layer.width - sourceX);
			var sourceH:Number = imageH;
			var destX:Number = 0;
			var destY:Number = offset;
			var destW:Number = Math.floor(width * (sourceW / imageW));
			var destH:Number = height;
			
			ctx.drawImage(atlas, sourceX, sourceY, sourceW, sourceH, destX, destY, destW, destH);
			if (sourceW < imageW)
			{
				ctx.drawImage(atlas, layer.x, sourceY, imageW - sourceW, sourceH, destW - 1, destY, width - destW, destH);
			}
		}
		
		
		public static function sprite(ctx:RenderBuffer, width:Number, height:Number, resolution:Number,
			roadWidth:Number, atlas:TextureAtlas, sprite:Image2D, SPRITES:Sprites, scale:Number, destX:Number,
			destY:Number, offsetX:Number, offsetY:Number, clipY:Number = NaN):void
		{
			// scale for projection AND relative to roadWidth (for tweakUI)
			var destW:Number = (sprite.width * scale * width / 2) * (SPRITES.SCALE * roadWidth);
			var destH:Number = (sprite.height * scale * width / 2) * (SPRITES.SCALE * roadWidth);

			destX = destX + (destW * (offsetX || 0));
			destY = destY + (destH * (offsetY || 0));

			var clipH:Number = clipY ? Math.max(0, destY + destH - clipY) : 0;
			if (clipH < destH)
			{
				ctx.drawImage(atlas, sprite.x, sprite.y, sprite.width, sprite.height - (sprite.height * clipH / destH), destX, destY, destW, destH - clipH);
			}
		}
		
		
		public static function player(ctx:RenderBuffer, width:Number, height:Number, resolution:Number,
			roadWidth:Number, atlas:TextureAtlas, SPRITES:Sprites, speedPercent:Number, scale:Number,
			destX:Number, destY:Number, steer:Number, updown:Number):void
		{
			var bounce:Number = (1.5 * Math.random() * speedPercent * resolution) * Util.randomChoice([-1, 1]);
			var spr:Image2D;
			
			if (steer < 0)
			{
				spr = (updown > 0) ? SPRITES.PLAYER_UPHILL_LEFT : SPRITES.PLAYER_LEFT;
			}
			else if (steer > 0)
			{
				spr = (updown > 0) ? SPRITES.PLAYER_UPHILL_RIGHT : SPRITES.PLAYER_RIGHT;
			}
			else
			{
				spr = (updown > 0) ? SPRITES.PLAYER_UPHILL_STRAIGHT : SPRITES.PLAYER_STRAIGHT;
			}

			sprite(ctx, width, height, resolution, roadWidth, atlas, spr, SPRITES, scale, destX, destY + bounce, -0.5, -1);
		}
		
		
		public static function fog(ctx:RenderBuffer, x:Number, y:Number, width:Number, height:Number,
			fog:Number):void
		{
			if (fog < 1)
			{
				ctx.globalAlpha = (1 - fog);
				ctx.fillStyle = COLORS.FOG;
				ctx.fillRect(x, y, width, height);
				ctx.globalAlpha = 1;
			}
		}
		
		
		public static function rumbleWidth(projectedRoadWidth:Number, lanes:int):Number
		{
			return projectedRoadWidth / Math.max(6, 2 * lanes);
		}
		
		
		public static function laneMarkerWidth(projectedRoadWidth:Number, lanes:int):Number
		{
			return projectedRoadWidth / Math.max(32, 8 * lanes);
		}
	}
}
