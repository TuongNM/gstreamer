--  -*-haskell-*-
--  GIMP Toolkit (GTK) Region
--
--  Author : Axel Simon
--  Created: 22 September 2002
--
--  Version $Revision: 1.1 $ from $Date: 2004/11/21 15:06:14 $
--
--  Copyright (c) 2002 Axel Simon
--
--  This library is free software; you can redistribute it and/or
--  modify it under the terms of the GNU Library General Public
--  License as published by the Free Software Foundation; either
--  version 2 of the License, or (at your option) any later version.
--
--  This library is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
--  Library General Public License for more details.
--
-- |
--
-- A set of rectangles describing areas to be redrawn.
--
-- * Regions consist of a set of non-overlapping rectangles. They are used to
--   specify the area of a window which needs updating.
--
-- TODO
--
-- * The Span functions and callbacks are not implemented since retrieving
--   a set of rectangles and working on them within Haskell seems to be easier.
--
module Region(
  makeNewRegion,
  Region(Region),
  regionNew,
  FillRule(..),
  regionPolygon,
  regionCopy,
  regionRectangle,
  regionGetClipbox,
  regionGetRectangles,
  regionEmpty,
  regionEqual,
  regionPointIn,
  OverlapType(..),
  regionRectIn,
  regionOffset,
  regionShrink,
  regionUnionWithRect,
  regionIntersect,
  regionUnion,
  regionSubtract,
  regionXor) where

import Monad	(liftM)
import FFI
import Structs	(Point, Rectangle(..))
import GdkEnums (FillRule(..), OverlapType(..))

{# context lib="gtk" prefix="gdk" #}

{#pointer *GdkRegion as Region foreign newtype #}

-- Construct a region from a pointer.
--
makeNewRegion :: Ptr Region -> IO Region
makeNewRegion rPtr = do
  region <- newForeignPtr rPtr (region_destroy rPtr)
  return (Region region)

#if __GLASGOW_HASKELL__>=600

foreign import ccall unsafe "&gdk_region_destroy"
  region_destroy' :: FinalizerPtr Region

region_destroy :: Ptr Region -> FinalizerPtr Region
region_destroy _ = region_destroy'

#elif __GLASGOW_HASKELL__>=504

foreign import ccall unsafe "gdk_region_destroy"
  region_destroy :: Ptr Region -> IO ()

#else

foreign import ccall "gdk_region_destroy" unsafe
  region_destroy :: Ptr Region -> IO ()

#endif


-- | Create an empty region.
--
regionNew :: IO Region
regionNew = do
  rPtr <- {#call unsafe region_new#}
  makeNewRegion rPtr

-- | Convert a polygon into a 'Region'.
--
regionPolygon :: [Point] -> FillRule -> IO Region
regionPolygon points rule =
  withArray (concatMap (\(x,y) -> [fromIntegral x, fromIntegral y]) points) $
  \(aPtr :: Ptr {#type gint#}) -> do
    rPtr <- {#call unsafe region_polygon#} (castPtr aPtr) 
	    (fromIntegral (length points)) ((fromIntegral.fromEnum) rule)
    makeNewRegion rPtr

-- | Copy a 'Region'.
--
regionCopy :: Region -> IO Region
regionCopy r = do
  rPtr <- {#call unsafe region_copy#} r
  makeNewRegion rPtr

-- | Convert a rectangle to a 'Region'.
--
regionRectangle :: Rectangle -> IO Region
regionRectangle rect = withObject rect $ \rectPtr -> do
  regPtr <- {#call unsafe region_rectangle#} (castPtr rectPtr)
  makeNewRegion regPtr

-- | Smallest rectangle including the 
-- 'Region'.
--
regionGetClipbox :: Region -> IO Rectangle
regionGetClipbox r = alloca $ \rPtr -> do
  {#call unsafe region_get_clipbox#} r (castPtr rPtr)
  peek rPtr

-- | Turn the 'Region' into its rectangles.
--
-- * A 'Region' is a set of horizontal bands. Each band
--   consists of one or more rectangles of the same height. No rectangles
--   in a band touch.
--
regionGetRectangles :: Region -> IO [Rectangle]
regionGetRectangles r = 
  alloca $ \(aPtr :: Ptr Rectangle) -> 
  alloca $ \(iPtr :: Ptr {#type gint#}) -> do
    {#call unsafe region_get_rectangles#} r (castPtr aPtr) iPtr
    size <- peek iPtr
    regs <- peekArray (fromIntegral size) aPtr
    {#call unsafe g_free#} (castPtr aPtr)
    return regs

-- | Test if a 'Region' is empty.
--
regionEmpty :: Region -> IO Bool
regionEmpty r = liftM toBool $ {#call unsafe region_empty#} r

-- | Compares two 'Region's for equality.
--
regionEqual :: Region -> Region -> IO Bool
regionEqual r1 r2 = liftM toBool $ {#call unsafe region_equal#} r1 r2

-- | Checks if a point it is within a region.
--
regionPointIn :: Region -> Point -> IO Bool
regionPointIn r (x,y) = liftM toBool $ 
  {#call unsafe region_point_in#} r (fromIntegral x) (fromIntegral y)

-- | Check if a rectangle is within a region.
--
regionRectIn :: Region -> Rectangle -> IO OverlapType
regionRectIn reg rect = liftM (toEnum.fromIntegral) $ withObject rect $
  \rPtr -> {#call unsafe region_rect_in#} reg (castPtr rPtr)

-- | Move a region.
--
regionOffset :: Region -> Int -> Int -> IO ()
regionOffset r dx dy = 
  {#call unsafe region_offset#} r (fromIntegral dx) (fromIntegral dy)

-- | Move a region.
--
-- * Positive values shrink the region, negative values expand it.
--
regionShrink :: Region -> Int -> Int -> IO ()
regionShrink r dx dy = 
  {#call unsafe region_shrink#} r (fromIntegral dx) (fromIntegral dy)

-- | Updates the region to include the rectangle.
--
regionUnionWithRect :: Region -> Rectangle -> IO ()
regionUnionWithRect reg rect = withObject rect $ \rPtr ->
  {#call unsafe region_union_with_rect#} reg (castPtr rPtr)

-- | Intersects one region with another.
--
-- * Changes @reg1@ to include the common areas of @reg1@
--   and @reg2@.
--
regionIntersect :: Region -> Region -> IO ()
regionIntersect reg1 reg2 = {#call unsafe region_intersect#} reg1 reg2

-- | Unions one region with another.
--
-- * Changes @reg1@ to include @reg1@ and @reg2@.
--
regionUnion :: Region -> Region -> IO ()
regionUnion reg1 reg2 = {#call unsafe region_union#} reg1 reg2

-- | Removes pars of a 'Region'.
--
-- * Reduces the region @reg1@ so that is does not include any areas
--   of @reg2@.
--
regionSubtract :: Region -> Region -> IO ()
regionSubtract reg1 reg2 = {#call unsafe region_subtract#} reg1 reg2

-- | XORs two 'Region's.
--
-- * The exclusive or of two regions contains all areas which were not
--   overlapping. In other words, it is the union of the regions minus
--   their intersections.
--
regionXor :: Region -> Region -> IO ()
regionXor reg1 reg2 = {#call unsafe region_xor#} reg1 reg2

