{-# language RankNTypes #-}
{-# language TypeOperators #-}
{-# language UndecidableInstances #-}
{-# language DefaultSignatures #-}
{-# language FlexibleContexts #-}
{-# language LambdaCase #-}

-- |
-- Copyright :  (c) Edward Kmett 2018
-- License   :  BSD-2-Clause OR Apache-2.0
-- Maintainer:  Edward Kmett <ekmett@gmail.com>
-- Stability :  experimental
-- Portability: non-portable
--
-- Based on <http://sebfisch.github.io/explicit-sharing/>

module Sharing where

import Control.Monad.State.Class
import GHC.Generics
import Ref.Base
import Ref.Key

class GShareable f where
  gsharing
    :: (MonadState s m, HasRefEnv s (KeyState m), MonadKey m)
    => (forall b. Shareable b => m b -> m (m b))
    -> f a -> m (f a)

instance Shareable c => GShareable (K1 i c) where
  gsharing f (K1 m) = K1 <$> sharing f m

instance GShareable f => GShareable (M1 i c f) where
  gsharing f (M1 m) = M1 <$> gsharing f m

instance (GShareable f, GShareable g) => GShareable (f :*: g) where
  gsharing f (x :*: y) = (:*:) <$> gsharing f x <*> gsharing f y

instance (GShareable f, GShareable g) => GShareable (f :+: g) where
  gsharing f (L1 x) = L1 <$> gsharing f x
  gsharing f (R1 x) = R1 <$> gsharing f x

instance (Shareable1 f, GShareable g) => GShareable (f :.: g) where
  gsharing f (Comp1 x) = Comp1 <$> sharing1 (gsharing) f x

class Shareable a where
  sharing
    :: (MonadState s m, HasRefEnv s (KeyState m), MonadKey m)
    => (forall b. Shareable b => m b -> m (m b))
    -> a -> m a
  default sharing
    :: (Generic a, GShareable (Rep a), MonadState s m, HasRefEnv s (KeyState m), MonadKey m)
    => (forall b. Shareable b => m b -> m (m b))
    -> a -> m a
  sharing f m = to <$> gsharing f (from m)

instance Shareable () where sharing _ = return
instance Shareable Char where sharing _ = return
instance Shareable Bool where sharing _ = return
instance Shareable Int where sharing _ = return
instance (Shareable a, Shareable b) => Shareable (a, b)

class Shareable1 f where
  sharing1
    :: (MonadState s m, HasRefEnv s (KeyState m), MonadKey m)
    => ((forall b. Shareable b => m b -> m (m b)) -> a -> m a)
    -> (forall b. Shareable b => m b -> m (m b)) -> (f a) -> m (f a)
  default sharing1
    :: (Generic1 f, Shareable1 (Rep1 f), MonadState s m, HasRefEnv s (KeyState m), MonadKey m)
    => ((forall b. Shareable b => m b -> m (m b)) -> a -> m a)
    -> (forall b. Shareable b => m b -> m (m b)) -> (f a) -> m (f a)
  sharing1 g f m = to1 <$> sharing1 g f (from1 m)

instance Shareable c => Shareable1 (K1 i c) where
  sharing1 _ f (K1 m) = K1 <$> sharing f m

instance Shareable1 f => Shareable1 (M1 i c f) where
  sharing1 g f (M1 m) = M1 <$> sharing1 g f m

instance (Shareable1 f, Shareable1 g) => Shareable1 (f :*: g) where
  sharing1 g f (x :*: y) = (:*:) <$> sharing1 g f x <*> sharing1 g f y

instance (Shareable1 f, Shareable1 g) => Shareable1 (f :+: g) where
  sharing1 g f (L1 x) = L1 <$> sharing1 g f x
  sharing1 g f (R1 x) = R1 <$> sharing1 g f x

instance (Shareable1 f, Shareable1 g) => Shareable1 (f :.: g) where
  sharing1 g f (Comp1 x) = Comp1 <$> sharing1 (sharing1 g) f x

eval :: (MonadState s m, HasRefEnv s (KeyState m), MonadKey m, Shareable a) => a -> m a
eval = sharing $ \a -> a >>= eval >>= return . return

share ::  (MonadState s m, HasRefEnv s (KeyState m), MonadKey m, Shareable a) => m a -> m (m a)
share m = memo $ m >>= sharing share
