# USDC LXLY

## USDC LXLY Architecture and User Flows

![Diagram](./usdc-lxly.jpg)

[USDC-e LxLy](https://docs.google.com/document/d/1heUd3Cbux-ngnCJITbKJ9pdsz26BmNz1hfOn9NTuDH8/edit?pli=1)

## Contracts

- **BridgedWrapped USDC** (zkEVM) - existing token for USDC in zkEVM, created by the Polygon ZkEVMBridge using the default TokenWrapped ERC20 contract.

- **USDC-e** (zkEVM) - "Native" USDC in zkEVM. This contract matches the current USDC contract deployed on Ethereum, with all expected features. The contract address is different from the current "bridge wrapped" USDC in use today, and has the ability to issue and burn tokens as well as "blacklist" addresses. [See USDC-e project](https://github.com/omnifient/usdc-e).

- **L1Escrow** (L1) - This contract receives L1 USDC from users, and triggers the ZkMinterBurner contract on zkEVM (through the Polygon ZkEVM Bridge) to mint USDC-e. It holds all of the L1 backing of USDC-e.
  It's also triggered by the Bridge to withdraw L1 USDC.

- **ZkMinterBurner** (zkEVM) - This contract receives USDC-e from users on zkEVM, burns it, and triggers the L1Escrow contract on Ethereum Mainnet (through the Polygon ZkEVM Bridge) to transfer L1 USDC to the user.
  It's also triggered by the Bridge to mint USDC-e when the Bridge receives a message from the L1Escrow that a user has deposited L1 USDC.

- **NativeConverter** (zkEVM) - This contract receives BridgeWrappedUSDC on zkEVM and mints back USDC-e. It also has a permissionless publicly callable function called "migrate" which withdraws all BridgedWrappedUSDC to L1 through the Bridge. The beneficiary address is the L1Escrow, thus migrating the supply and settling the balance.

## Access Control

- L1Escrow
  - Pauser/Unpauser
  - Admin Upgrader (via UUPS proxies)
  - Change Owner (which controls the ability to pause/unpause)
  - Change Admin (which controls the ability to upgrade the contracts)
- ZkMinterBurner
  - Pauser/Unpauser
  - Admin Upgrader (via UUPS proxies)
  - Change Owner (which controls the ability to pause/unpause)
  - Change Admin (which controls the ability to upgrade the contracts)
  - Minter of USDC-e (set by the USDC-e deploy script)
  - Burner of USDC-e (set by the USDC-e deploy script)
- NativeConverter
  - Pauser/Unpauser
  - Admin Upgrader (via UUPS proxies)
  - Change Owner (which controls the ability to pause/unpause)
  - Change Admin (which controls the ability to upgrade the contracts)
  - Minter of USDC-e (set by the USDC-e deploy script)
  - Burner of USDC-e (set by the USDC-e deploy script)
    - Note: `burn` is never used by the NativeConverter, only `mint`

## Flows

- User Bridges from L1 to zkEVM
  - User calls `bridgeToken()` on L1Escrow, L1_USDC transferred to L1Escrow, message sent to PolygonZkEVMBridge targeted to zkEVM’s ZkMinterBurner.
  - Message claimed and sent to ZkMinterBurner, which calls `mint()` on USDC-e, which mints new supply to the correct address.
- User Bridges from zkEVM to L1
  - User calls `bridgeToken()` on ZkMinterBurner which calls `burn()` on USDC-e, burning the supply. Message is sent to PolygonZkEVMBridge targeted to L1Escrow.
  - Message claimed and sent to L1Escrow, which transfers L1_USDC to the correct address.
- User converts BridgeWrappedUSDC to USDC-e
  - User calls `convert()` on NativeConverter, BridgeWrappedUSDC is transferred to NativeConverter. NativeConverter calls `mint()` on USDC-e, which mints new supply to the correct address.
  - Anyone can call `migrate()` on NativeConverter to have all BridgeWrappedUSDC withdrawn via the PolygonZkEVMBridge moving the L1_USDC held in the PolygonZkEVMBridge to L1Escrow.

## Testing and Deploying

First, copy `.env.example` to `.env` and set the appropriate environment variables (annotated with TODOs).

### Testing

1. Start anvil: two instances required, one for L1, and one for L2

```bash
# 1.1 start L1 (ethereum mainnet) anvil - NOTE: using port 8001 for L1
anvil --fork-url <https://eth-mainnet.g.alchemy.com/v2/YOUR_ALCHEMY_KEY> --chain-id 1 --port 8001 --fork-block-number 17785773

# 1.2 start L2 (polygon zkevm) anvil - NOTE: using port 8101 for L2
anvil --fork-url <https://polygonzkevm-mainnet.g.alchemy.com/v2/YOUR_ALCHEMY_KEY> --chain-id 1101 --port 8101 --fork-block-number 3172683
```

2. Deploy and initialize USDC-e in L2. Make sure you have the `usdc-e/` project configured.

```bash
cd usdc-e/
forge script script/DeployInitUSDCE.s.sol:DeployInitUSDCE --fork-url http://localhost:8101 --broadcast --verify -vvvv
```

3. Copy the address to where USDC-e was deployed (to be used in the next step)

```bash
FiatTokenV2_1@0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
```

4. Set the USDC-e address into `usdc-lxly/.env`

```bash
cd usdc-lxly/
ADDRESS_L2_USDC=0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
```

5. Run the usdc-lxly tests

```bash
cd usdc-lxly/
forge test -v
```

### Deployment to Mainnet Forks

Note:

- using `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` as the admin for USDC-e
- using `0xa0Ee7A142d267C1f36714E4a8F75612F20a79720` as the admin+owner for L1Escrow, ZkMinterBurner, and NativeConverter contracts

A. Follow steps 1-4 from testing

B. deploy and initialize usdc-lxly

```bash
cd usdc-lxly/
forge script scripts/DeployInit.s.sol:DeployInit --broadcast -vvvv
```

### Deployment to Testnet/Mainnet

1. Deploy and initialize USDC-e in L2. Make sure you have the `usdc-e/` project configured.

```bash
cd usdc-e/
forge script script/DeployInitUSDCE.s.sol:DeployInitUSDCE --fork-url https://rpc.public.zkevm-test.net --broadcast -vvvvv
```

2. Copy the address to where USDC-e was deployed (to be used in the next step)

```bash
FiatTokenV2_1@0x00...000
```

3. Set the USDC-e address into `usdc-lxly/.env`

```bash
cd usdc-lxly/
ADDRESS_L2_USDC=0x00...000
```

4. deploy and initialize usdc-lxly

```bash
cd usdc-lxly/
forge script scripts/DeployInit.s.sol:DeployInit --broadcast -vvvv
```
