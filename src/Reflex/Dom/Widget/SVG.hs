{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE RankNTypes            #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeFamilies          #-}
module Reflex.Dom.Widget.SVG where

import           Data.Text                   (Text)

import           Reflex                      (Dynamic)
import qualified Reflex                      as R

import           Reflex.Dom                  (DomBuilderSpace, Element,
                                              EventResult, MonadWidget)
import qualified Reflex.Dom                  as RD

import           Data.Map                    (Map)
import qualified Data.Map                    as Map

import           Reflex.Dom.Widget.SVG.Types (SVG_El, SVG_Rect, makeRectProps,
                                              makeSVGProps)

class AsSVGTag s where
  svgTagName :: s -> Text

instance AsSVGTag BasicSVG where
  svgTagName Rectangle = "rect"
  svgTagName Circle    = "circle"
  svgTagName Ellipse   = "ellipse"
  svgTagName Path      = "path"
  svgTagName Line      = "line"
  svgTagName PolyLine  = "polyline"
  svgTagName Polygon   = "polygon"

instance AsSVGTag BasicInner where
  svgTagName Animate = "animate"

instance AsSVGTag SVG_Root where
  svgTagName SVG_Root = "svg"

data SVG_Root = SVG_Root

data BasicSVG
  = Rectangle
  | Circle
  | Ellipse
  | Path
  | Line
  | PolyLine
  | Polygon

data BasicInner
  = Animate
  deriving (Eq, Ord)

type family CanBeNested a :: *
type instance CanBeNested BasicSVG = BasicInner

data SVGEl t a = SVGEl
  { _svgEl_el       :: RD.El t
  , _svgEl_children :: Dynamic t (Map (CanBeNested a) (RD.El t))
  }

svgElDynAttr'
  :: forall t m a e. ( MonadWidget t m
                     , AsSVGTag e
                     )
  => e
  -> Dynamic t (Map Text Text)
  -> m a
  -> m (Element EventResult (DomBuilderSpace m) t, a)
svgElDynAttr' = RD.elDynAttrNS'
  ( Just "http://www.w3.org/2000/svg" )
  . svgTagName

svgElDyn
  :: ( MonadWidget t m
     , AsSVGTag a
     , AsSVGTag (CanBeNested a)
     , Ord (CanBeNested a)
     )
  => a
  -> Dynamic t (Map Text Text)
  -> Dynamic t ( Map (CanBeNested a) (Map Text Text) )
  -> m ( SVGEl t a )
svgElDyn s dSAttrs dInnerElMap =
  fmap ( uncurry SVGEl ) . svgElDynAttr' s dSAttrs $ RD.listWithKey dInnerElMap
    (\innerS dInnerAttrs -> fst <$> svgElDynAttr' innerS dInnerAttrs RD.blank)

svgElDynAttrs_
  :: ( MonadWidget t m
     , AsSVGTag s
     )
  => s
  -> Dynamic t (Map Text Text)
  -> m (SVGEl t s)
svgElDynAttrs_ s dSAttrs = do
  (svgEl, _) <- svgElDynAttr' s dSAttrs RD.blank
  pure ( SVGEl svgEl (pure Map.empty) )

svgElAttrs_
  :: ( MonadWidget t m
     , AsSVGTag s
     )
  => s
  -> Map Text Text
  -> m (SVGEl t s)
svgElAttrs_ s sAttrs =
  svgElDynAttrs_ s ( pure sAttrs )

svg_
  :: ( MonadWidget t m
     , R.Reflex t
     , AsSVGTag a
     )
  => Dynamic t SVG_El
  -> m ( SVGEl t a )
  -> m ( RD.El t, SVGEl t a)
svg_ dAttrs =
  svgElDynAttr' SVG_Root (makeSVGProps <$> dAttrs)

-- Helpers ?

-- There has to be a nicer way of tying these together :/

svgBasicDyn
  :: ( MonadWidget t m
     , AsSVGTag s
     , AsSVGTag (CanBeNested s)
     , Ord (CanBeNested s)
     )
  => s
  -> ( p -> Map Text Text )
  -> Dynamic t p
  -> Dynamic t ( Map (CanBeNested s) (Map Text Text) )
  -> m ( SVGEl t s )
svgBasicDyn t propFn dProps =
  svgElDyn t (propFn <$> dProps)

svgBasicDyn_
  :: ( MonadWidget t m
     , AsSVGTag s
     , AsSVGTag (CanBeNested s)
     , Ord (CanBeNested s)
     )
  => s
  -> ( p -> Map Text Text )
  -> Dynamic t p
  -> m ( SVGEl t s )
svgBasicDyn_ t propFn dProps =
  svgBasicDyn t propFn dProps (pure mempty)

-- Example functions for simple rectangle.
svgRectDyn_
  :: MonadWidget t m
  => Dynamic t SVG_Rect
  -> m ( SVGEl t BasicSVG )
svgRectDyn_ =
  svgBasicDyn_ Rectangle makeRectProps

svgRectDyn
  :: MonadWidget t m
  => Dynamic t SVG_Rect
  -> Dynamic t ( Map BasicInner (Map Text Text) )
  -> m ( SVGEl t BasicSVG )
svgRectDyn =
  svgBasicDyn Rectangle makeRectProps
