{-# LANGUAGE DeriveDataTypeable #-}
module Kafka.Producer.Types
( KafkaProducer(..)
, ProducerRecord(..)
, ProducePartition(..)
, DeliveryReport(..)
)
where

import qualified Data.ByteString      as BS
import           Data.Typeable        (Typeable)
import           Kafka.Internal.Setup (HasKafka(..), HasKafkaConf(..), HasTopicConf(..), Kafka(..), KafkaConf(..), TopicConf(..))
import           Kafka.Types          (TopicName(..), KafkaError(..))
import           Kafka.Consumer.Types (Offset(..))

-- | Main pointer to Kafka object, which contains our brokers
data KafkaProducer = KafkaProducer
  { kpKafkaPtr  :: !Kafka
  , kpKafkaConf :: !KafkaConf
  , kpTopicConf :: !TopicConf
  }

instance HasKafka KafkaProducer where
  getKafka = kpKafkaPtr
  {-# INLINE getKafka #-}

instance HasKafkaConf KafkaProducer where
  getKafkaConf = kpKafkaConf
  {-# INLINE getKafkaConf #-}

instance HasTopicConf KafkaProducer where
  getTopicConf = kpTopicConf
  {-# INLINE getTopicConf #-}

-- | Represents messages /to be enqueued/ onto a Kafka broker (i.e. used for a producer)
data ProducerRecord = ProducerRecord
  { prTopic     :: !TopicName
  , prPartition :: !ProducePartition
  , prKey       :: Maybe BS.ByteString
  , prValue     :: Maybe BS.ByteString
  } deriving (Eq, Show, Typeable)

data ProducePartition =
    SpecifiedPartition {-# UNPACK #-} !Int  -- the partition number of the topic
  | UnassignedPartition
  deriving (Show, Eq, Ord, Typeable)

data DeliveryReport
  = DeliverySuccess ProducerRecord Offset
  | DeliveryFailure ProducerRecord KafkaError
  | NoMessageError KafkaError
  deriving (Show, Eq)

-- -- | Represents the report of a successfully delivered message.
-- data ProducerSuccess = ProducerSuccess
--   { psTopic     :: !TopicName    -- ^ Kafka topic this message was received from
--   , psPartition :: !PartitionId  -- ^ Kafka partition this message was received from
--   , psOffset    :: !Offset       -- ^ Offset within the 'crPartition' Kafka partition
--   , psKey       :: !(Maybe BS.ByteString)
--   , psValue     :: !(Maybe BS.ByteString)
--   }
--   deriving (Eq, Show, Read, Typeable)

-- -- | Represents the failure to deliver a message.
-- data ProducerError = ProducerError
--   { peValue :: !(Maybe BS.ByteString)  -- ^ The message that failed.
--   , peError :: KafkaError              -- ^ The reason for the failure.
--   } deriving (Eq, Show)
