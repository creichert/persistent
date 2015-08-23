{-# LANGUAGE CPP #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleContexts #-}
module Database.Persist
    ( module Database.Persist.Class
    , module Database.Persist.Types

      -- * query combinators
    , (=.), (+=.), (-=.), (*=.), (/=.)
    , (==.), (!=.), (<.), (>.), (<=.), (>=.)
    , (<-.), (/<-.)
    , (||.)

      -- * JSON Utilities
    , listToJSON
    , mapToJSON
    , toJsonText
    , getPersistMap

      -- * Other utililities
    , limitOffsetOrder
    ) where

import Database.Persist.Types
import Database.Persist.Class
import Database.Persist.Class.PersistField (getPersistMap)
import qualified Data.Text as T
import Data.Text.Lazy (toStrict)
import Data.Text.Lazy.Builder (toLazyText)
import Data.Aeson (toJSON, ToJSON)
#if MIN_VERSION_aeson(0, 7, 0)
import Data.Aeson.Encode (encodeToTextBuilder)
#else
import Data.Aeson.Encode (fromValue)
#endif

infixr 3 =., +=., -=., *=., /=.
(=.), (+=.), (-=.), (*=.), (/=.) :: forall v typ.  PersistField typ => EntityField v typ -> typ -> Update v
-- | assign a field a value
f =. a = Update f a Assign
-- | assign a field by addition (+=)
f +=. a = Update f a Add
-- | assign a field by subtraction (-=)
f -=. a = Update f a Subtract
-- | assign a field by multiplication (*=)
f *=. a = Update f a Multiply
-- | assign a field by division (/=)
f /=. a = Update f a Divide

infix 4 ==., <., <=., >., >=., !=.
(==.), (!=.), (<.), (<=.), (>.), (>=.) ::
  forall v typ.  PersistField typ => EntityField v typ -> typ -> Filter v
f ==. a  = Filter f (Left a) Eq
f !=. a = Filter f (Left a) Ne
f <. a  = Filter f (Left a) Lt
f <=. a  = Filter f (Left a) Le
f >. a  = Filter f (Left a) Gt
f >=. a  = Filter f (Left a) Ge

infix 4 <-., /<-.
(<-.), (/<-.) :: forall v typ.  PersistField typ => EntityField v typ -> [typ] -> Filter v
-- | In
f <-. a = Filter f (Right a) In
-- | NotIn
f /<-. a = Filter f (Right a) NotIn

infixl 3 ||.
(||.) :: forall v. [Filter v] -> [Filter v] -> [Filter v]
-- | the OR of two lists of filters. For example: 
-- selectList([PersonAge >. 25, PersonAge <. 30] ||. [PersonIncome >. 15000, PersonIncome <. 25000]) []
-- will filter records where a person's age is between (25 and 30) OR a person's income is between (15,000 and 25000). 
-- If you are looking for an &&. operator to do (A AND B AND (C OR D)) you can use the ++ operator instead as there is no &&. For example: 
-- selectList([PersonAge >. 25, PersonAge <. 30] ++ ([PersonCategory ==. 1] ||.  [PersonCategory ==. 5])) []
-- will filter records where a person's age is between (25 and 30) AND (person's category is either 1 or 5)  
a ||. b = [FilterOr  [FilterAnd a, FilterAnd b]]

listToJSON :: [PersistValue] -> T.Text
listToJSON = toJsonText

mapToJSON :: [(T.Text, PersistValue)] -> T.Text
mapToJSON = toJsonText

toJsonText :: ToJSON j => j -> T.Text
#if MIN_VERSION_aeson(0, 7, 0)
toJsonText = toStrict . toLazyText . encodeToTextBuilder . toJSON
#else
toJsonText = toStrict . toLazyText . fromValue . toJSON
#endif

limitOffsetOrder :: PersistEntity val => [SelectOpt val] -> (Int, Int, [SelectOpt val])
limitOffsetOrder opts =
    foldr go (0, 0, []) opts
  where
    go (LimitTo l) (_, b, c) = (l, b ,c)
    go (OffsetBy o) (a, _, c) = (a, o, c)
    go x (a, b, c) = (a, b, x : c)
