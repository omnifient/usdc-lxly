# USDC LXLY

## Description

[USDC LxLy](https://docs.google.com/document/d/1heUd3Cbux-ngnCJITbKJ9pdsz26BmNz1hfOn9NTuDH8/edit?pli=1)

## Contracts

- ~~USDC.e (zkEVM) - This contract will match the current USDC contract deployed on Ethereum, with all expected features. Its contract address will be different from the current “wrapped” USDC in use today, and will have the ability to issue and burn tokens as well as “blacklist” addresses.~~ [usdc-e project](https://github.com/omnifient/usdc-e)

- BridgeMinter (zkEVM) - This contract will receive messages from the LXLY bridge on zkEVM, it will hold the minter role giving it the ability to mint USDC.e based on instructions from LXLY from Ethereum only. This contract will be upgradable.

- BridgeBurner (zkEVM) - This contract will send messages to LXLY bridge on zkEVM, it will hold the burner role giving it the ability to burn USDC.e based on instructions from LXLY, triggering a release of assets on L1Escrow. This contract will be upgradable.

- L1Escrow (L1) - This contract will receive USDC from users on L1 and trigger BridgeMinter on the zkEVM via LxLy. This contract will be upgradable. This contract will hold all of the backing for USDC on zkEVM.

- NativeConverter (zkEVM) - This contract will receive BridgeWrappedUSDC on zkEVM and issue USDC.e on zkEVM. This contract will hold the minter role giving it the ability to mint USDC.e based on inflows of BridgeWrappedUSDC. This contract will also have a permissionless publicly callable function called “migrate” which when called will withdraw all BridgedWrappedUSDC to L1 via the LXLY bridge. The beneficiary address will be the L1Escrow, thus migrating the supply and settling the balance. This contract will be upgradable and pausable.

## Flows

- User Bridges from L1 to zkEVM (post upgrade to USDC.e)
  - User calls deposit() on L1Escrow, L1_USDC transferred to L1Escrow, message sent to zkEVMBridge targeted to zkEVM’s BridgeMinter.
  - Message claimed and sent to BridgeMinter, which calls mint() on NativeUSDC which mints new supply to the correct address.
- User Bridges from zkEVM to L1 (post upgrade to USDC.e)
  - User calls withdraw() on BridgeBurner which calls burn() on NativeUSDC burning the supply. Message is sent to zkEVMBridge targeted to L1Escrow.
  - Message claimed and sent to L1Escrow, which transfers L1_USDC to the correct address.
- User converts BridgeWrappedUSDC to USDC.e
  - User calls convert() on NativeConverter, BridgeWrappedUSDC is transferred to NativeConverter. NativeConverter calls mint() on NativeUSDC which mints new supply to the correct address.
  - Anyone can call migrate() on NativeConverter to have all BridgeWrappedUSDC withdrawn via the zkEVMBridge moving the L1_USDC held in the zkEVMBridge to L1Escrow.
