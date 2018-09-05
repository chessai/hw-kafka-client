{-# LANGUAGE DeriveDataTypeable #-}
module Kafka.Consumer.Types
( KafkaConsumer(..)
, ConsumerGroupId(..)
, Offset(..)
, OffsetReset(..)
, RebalanceEvent(..)
, PartitionOffset(..)
, SubscribedPartitions(..)
, Timestamp(..)
, OffsetCommit(..)
, OffsetStoreSync(..)
, OffsetStoreMethod(..)
, TopicPartition(..)
, ConsumerRecord(..)
, crMapKey
, crMapValue
, crMapKV
-- why are these here?
, sequenceFirst
, traverseFirst
, traverseFirstM
, traverseM
, bitraverseM
)
where

import Data.Text            (Text)
import Data.Bifoldable      (Bifoldable(..))
import Data.Bifunctor       (Bifunctor(..))
import Data.Bitraversable   (Bitraversable(..), bimapM, bisequenceA)
import Data.Int             (Int64)
import Data.Typeable        (Typeable)
import Kafka.Internal.Setup (HasKafka(..), HasKafkaConf(..), Kafka(..), KafkaConf(..))
import Kafka.Types          (TopicName(..), PartitionId(..), Millis(..))

data KafkaConsumer = KafkaConsumer
  { kcKafkaPtr  :: !Kafka
  , kcKafkaConf :: !KafkaConf
  }

instance HasKafka KafkaConsumer where
  getKafka = kcKafkaPtr
  {-# INLINE getKafka #-}

instance HasKafkaConf KafkaConsumer where
  getKafkaConf = kcKafkaConf
  {-# INLINE getKafkaConf #-}

newtype ConsumerGroupId = ConsumerGroupId { unConsumerGroupId :: Text } deriving (Show, Ord, Eq)
newtype Offset          = Offset { unOffset :: Int64 } deriving (Show, Eq, Ord, Read)
data OffsetReset        = Earliest | Latest deriving (Show, Eq)

-- | A set of events which happen during the rebalancing process
data RebalanceEvent =
    -- | Happens before Kafka Client confirms new assignment
    RebalanceBeforeAssign [(TopicName, PartitionId)]
    -- | Happens after the new assignment is confirmed
  | RebalanceAssign [(TopicName, PartitionId)]
    -- | Happens before Kafka Client confirms partitions rejection
  | RebalanceBeforeRevoke [(TopicName, PartitionId)]
    -- | Happens after the rejection is confirmed
  | RebalanceRevoke [(TopicName, PartitionId)]
  deriving (Eq, Show)

data PartitionOffset =
    PartitionOffsetBeginning
  | PartitionOffsetEnd
  | PartitionOffset Int64
  | PartitionOffsetStored
  | PartitionOffsetInvalid
  deriving (Eq, Show)

data SubscribedPartitions
  = SubscribedPartitions [PartitionId]
  | SubscribedPartitionsAll
  deriving (Show, Eq)

data Timestamp =
    CreateTime !Millis
  | LogAppendTime !Millis
  | NoTimestamp
  deriving (Show, Eq, Read)

-- | Offsets commit mode
data OffsetCommit =
      OffsetCommit       -- ^ Forces consumer to block until the broker offsets commit is done
    | OffsetCommitAsync  -- ^ Offsets will be committed in a non-blocking way
    deriving (Show, Eq)


-- | Indicates how offsets are to be synced to disk
data OffsetStoreSync =
      OffsetSyncDisable       -- ^ Do not sync offsets (in Kafka: -1)
    | OffsetSyncImmediate     -- ^ Sync immediately after each offset commit (in Kafka: 0)
    | OffsetSyncInterval Int  -- ^ Sync after specified interval in millis

-- | Indicates the method of storing the offsets
data OffsetStoreMethod =
      OffsetStoreBroker                         -- ^ Offsets are stored in Kafka broker (preferred)
    | OffsetStoreFile FilePath OffsetStoreSync  -- ^ Offsets are stored in a file (and synced to disk according to the sync policy)

-- | Kafka topic partition structure
data TopicPartition = TopicPartition
  { tpTopicName :: TopicName
  , tpPartition :: PartitionId
  , tpOffset    :: PartitionOffset
  } deriving (Show, Eq)

-- | Represents a /received/ message from Kafka (i.e. used in a consumer)
data ConsumerRecord k v = ConsumerRecord
  { crTopic     :: !TopicName    -- ^ Kafka topic this message was received from
  , crPartition :: !PartitionId  -- ^ Kafka partition this message was received from
  , crOffset    :: !Offset       -- ^ Offset within the 'crPartition' Kafka partition
  , crTimestamp :: !Timestamp    -- ^ Message timestamp
  , crKey       :: !k
  , crValue     :: !v
  }
  deriving (Eq, Show, Read, Typeable)

instance Bifunctor ConsumerRecord where
  bimap f g (ConsumerRecord t p o ts k v) =  ConsumerRecord t p o ts (f k) (g v)
  {-# INLINE bimap #-}

instance Functor (ConsumerRecord k) where
  fmap = second
  {-# INLINE fmap #-}

instance Foldable (ConsumerRecord k) where
  foldMap f r = f (crValue r)
  {-# INLINE foldMap #-}

instance Traversable (ConsumerRecord k) where
  traverse f r = (\v -> crMapValue (const v) r) <$> f (crValue r)
  {-# INLINE traverse #-}

instance Bifoldable ConsumerRecord where
  bifoldMap f g r = f (crKey r) `mappend` g (crValue r)
  {-# INLINE bifoldMap #-}

instance Bitraversable ConsumerRecord where
  bitraverse f g r = (\k v -> bimap (const k) (const v) r) <$> f (crKey r) <*> g (crValue r)
  {-# INLINE bitraverse #-}

crMapKey :: (k -> k') -> ConsumerRecord k v -> ConsumerRecord k' v
crMapKey = first
{-# INLINE crMapKey #-}

crMapValue :: (v -> v') -> ConsumerRecord k v -> ConsumerRecord k v'
crMapValue = second
{-# INLINE crMapValue #-}

crMapKV :: (k -> k') -> (v -> v') -> ConsumerRecord k v -> ConsumerRecord k' v'
crMapKV = bimap
{-# INLINE crMapKV #-}

sequenceFirst :: (Bitraversable t, Applicative f) => t (f k) v -> f (t k v)
sequenceFirst = bitraverse id pure
{-# INLINE sequenceFirst #-}

traverseFirst :: (Bitraversable t, Applicative f)
              => (k -> f k')
              -> t k v
              -> f (t k' v)
traverseFirst f = bitraverse f pure
{-# INLINE traverseFirst #-}

traverseFirstM :: (Bitraversable t, Applicative f, Monad m)
               => (k -> m (f k'))
               -> t k v
               -> m (f (t k' v))
traverseFirstM f r = bitraverse id pure <$> bitraverse f pure r
{-# INLINE traverseFirstM #-}

traverseM :: (Traversable t, Applicative f, Monad m)
          => (v -> m (f v'))
          -> t v
          -> m (f (t v'))
traverseM f r = sequenceA <$> traverse f r
{-# INLINE traverseM #-}

bitraverseM :: (Bitraversable t, Applicative f, Monad m)
            => (k -> m (f k'))
            -> (v -> m (f v'))
            -> t k v
            -> m (f (t k' v'))
bitraverseM f g r = bisequenceA <$> bimapM f g r
{-# INLINE bitraverseM #-}

