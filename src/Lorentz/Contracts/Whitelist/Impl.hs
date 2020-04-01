{-# LANGUAGE RebindableSyntax #-}

module Lorentz.Contracts.Whitelist.Impl where

import Prelude hiding ((>>), drop, swap, get)

import Lorentz
import Michelson.Text
import Michelson.Typed.Haskell.Value (IsComparable)

import Lorentz.Contracts.Whitelist.Types


--------------
-- Entrypoints
--------------

-- | Assert that one user is allowed to transfer to the other.
--
-- The `issuer` is allowed to transfer to anyone.
--
-- If the sender's `WhitelistId`'s `OutboundWhitelists` is `unrestricted`,
-- they may transfer to any receiver whose `WhitelistId` is in their
-- `allowedWhitelists`.
assertTransfer ::
     forall a s. (IsComparable a, CompareOpHs a, Typeable a)
  => TransferParams a & Storage a & s :-> ([Operation], Storage a) & s
assertTransfer = do
  dip $ do
    dup
    unStorage
    unpair
    dip car
    unpair
  unTransferParams
  swap
  dip $ do
    dup
    car
  ifEq
    (do
      drop
      drop
      drop
    )
    (do
      unpair
      assertUsersWhitelist @a
      swap
      dip $ do
        assertOutboundWhitelists
        assertUnrestrictedOutboundWhitelists
      mem
      assert $ mkMTextUnsafe "outbound not whitelisted"
    )
  nil
  pair

-- | Assert that all users are whitelisted and `unrestricted`, or the issuer
assertReceivers ::
     forall a s. (IsComparable a, CompareOpHs a)
  => [a] & Storage a & s :-> ([Operation], Storage a) & s
assertReceivers = do
  dip $ do
    dup
    unStorage
    unpair
    dip car
    unpair
  iter assertReceiver
  dropN @3
  nil
  pair

-- | Set the issuer
--
-- Only admin
setIssuer :: forall a. () => Entrypoint a (Storage a)
setIssuer = do
  dip $ do
    unStorage
    unpair
    dip $ do
      unpair
      dip $ assertAdmin
      pair
    cdr
  pair
  pair
  toStorage
  nil
  pair

-- | Assert not equal with an error: @"issuer is not a user"@
assertNotIssuer :: (CompareOpHs a, Typeable a) => a & a & s :-> a & a & s
assertNotIssuer = do
  dup
  dip $ do
    dip dup
    assertNeq $ mkMTextUnsafe "issuer is not a user"

-- | Add a user with a particular `WhitelistId`,
-- or implicitly remove by providing `Nothing`
--
-- Only admin
addUser :: forall a. (CompareOpHs a, Typeable a) => Entrypoint (UpdateUserParams a) (Storage a)
addUser = do
  dip $ do
    unStorage
    unpair
    dip $ do
      unpair
      dip $ do
        assertAdmin
      pair
    unpair
  unUpdateUserParams
  swap
  dip assertNotIssuer
  pair
  swap
  dip $ do
    unpair
    swap
    addUserWhitelist
  pair
  pair
  toStorage
  nil
  pair

-- | Set the `WhitelistOutboundParams` for a `WhitelistId`
--
-- Only admin
setWhitelistOutbound :: forall a. () => Entrypoint WhitelistOutboundParams (Storage a)
setWhitelistOutbound = do
  dip $ do
    unStorage
    unpair
    swap
    unpair
    dip assertAdmin
  unWhitelistOutboundParams
  setOutboundWhitelists
  pair
  swap
  pair
  toStorage
  nil
  pair

-- | Set the admin `Address`
--
-- Only admin
setAdmin :: forall a. () => Entrypoint Address (Storage a)
setAdmin = do
  dip $ do
    unStorage
    unpair
    dip $ do
      unpair
      dip $ do
        assertAdmin_
  swap
  dip $ do
    swap
    pair
  pair
  toStorage
  nil
  pair


------------------
-- View parameters
------------------

-- | Get the issuer, who may be set by the admin and is unrestricted
getIssuer :: forall a. (NiceParameter a) => Entrypoint (View_ a) (Storage a)
getIssuer =
  view_ $ do
    cdr
    unStorage
    car
    car

-- | Get a user's `WhitelistId`, or `Nothing` if the user is not present
getUser :: forall a. (IsComparable a) => Entrypoint (View a (Maybe WhitelistId)) (Storage a)
getUser =
  view_ $ do
    unpair
    dip $ do
      unStorage
      car
      cdr
    userWhitelist

-- | Get the `OutboundWhitelists` of a `WhitelistId` or `Nothing` if it's not present
getWhitelist :: forall a. () => Entrypoint (View WhitelistId (Maybe OutboundWhitelists)) (Storage a)
getWhitelist =
  view_ $ do
    unpair
    dip $ do
      unStorage
      cdr
      car
    outboundWhitelists

-- | Get the admin `Address` of the contract
getAdmin :: forall a. () => Entrypoint (View_ Address) (Storage a)
getAdmin =
  view_ $ do
    cdr
    unStorage
    cdr
    cdr


--------
-- Utils
--------

-- | Assert sender is the given address or fail with an error
assertAdmin_ :: Address & s :-> s
assertAdmin_ = do
  sender
  assertEq $ mkMTextUnsafe "only admin may update"

-- | `assertAdmin_`, but preserve the stack
assertAdmin :: Address & s :-> Address & s
assertAdmin = do
  dup
  dip assertAdmin_
