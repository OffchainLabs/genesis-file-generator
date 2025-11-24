# Genesis.json generator

This repository contains a script to generate a genesis.json file and obtain the block hash and sendRoot hash necessary to create an Arbitrum chain with a set of pre-deployed contracts at genesis.

## :exclamation: Important note about the chain config property

The genesis.json file generated in this repository contains the standard information of any regular genesis.json file used on an Ethereum chain. One of the properties of this file is the `config` property, which contains information about the [chain configuration](https://github.com/ethereum/go-ethereum/blob/master/params/config.go#L433). This chain configuration is used as a component to calculate the genesis blockhash of the chain.

When creating an Arbitrum chain with a non-zero genesis state, the chain configuration is used in 2 places:

- When calculating the genesis blockhash, using Nitro's [genesis-generator](https://github.com/OffchainLabs/nitro/blob/master/cmd/genesis-generator/genesis-generator.go) tool
- When creating the chain through the RollupCreator contract

Upon initialization, Nitro will use the chain configuration set on-chain (on chain creation) with the rest of the information of the genesis.json file, to obtain a genesis blockhash. It will then compare that blockhash with the one generated with Nitro's genesis-generator (which used the chain configuration directly set in the genesis.json file). For both blockhashes to match, the chain configuration must be exactly the same at the string level, including order of fields, potential whitespaces or special characters.

This repository generates a genesis.json file with a minified chain `config` property to match the minified string that is usually sent to the RollupCreator contract. If the genesis.json file is generated with a different tool, special attention must be taken to also minify the `config` property of the file.

## How to use this repository

Clone the repository

```shell
git clone https://github.com/OffchainLabs/genesis-file-generator.git
```

Make a copy of the environment variable and set the necessary values

```shell
cp .env.example .env
```

> [!NOTE]
> Make sure you set the correct values of the environment variables for your chain

Run the script

```shell
./generate.sh
```

The script will output two artifacts:

- A genesis.json file in `genesis/genesis.json`
- The genesis blockhash and sendRoot in the output of the script. For example:
    ```shell
    BlockHash: 0xc8718e3eb62b1fab6ce0ee050385a545c21423a3b164a91545ad9e097fbd5341, SendRoot: 0xac8636f211d5a9a31ca310b8061eb2696d875ee2fa90f903d913677b1f027aed
    ```

## How are contracts pre-deployed

This tool uses a Foundry script to deploy all contracts to the local chain created when running the script, and then fetches information about their state to craft the genesis.json file. Contracts are deployed following the same instructions than when deploying on a live chain, usually one of these methods:

- `CREATE2`
- `CREATE`
- Pre-signed transaction

### A note about storage accesses

When deploying a new contract, this script uses [vm.record](https://getfoundry.sh/reference/cheatcodes/record/) and [vm.accesses](https://getfoundry.sh/reference/cheatcodes/accesses) to get the storage slots that were written during the deployment operation. However, only the storage slots accessed on the deployed contract address are read.

If accesses to storage slots of any other address is needed in the future, `vm.record` and `vm.accesses` can be replaced by [vm.startStateDiffRecording](https://getfoundry.sh/reference/cheatcodes/start-state-diff-recording) and [vm.stopAndReturnStateDiff](https://getfoundry.sh/reference/cheatcodes/stop-and-return-state-diff), which return a more comprehensive diff.

## Pre-deployed contracts

This section lists the contracts that are pre-deployed (i.e., loaded into state at genesis).

- [Safe Singleton Factory](#safesingletonfactory-v1043)
- [GnosisSafe v1.3.0](#gnosissafe-v130)
- [GnosisSafeL2 v1.3.0](#gnosissafel2-v130)
- [GnosisSafeProxyFactory v1.3.0](#gnosissafeproxyfactory-v130)
- [MultiSend v1.3.0](#multisend-v130)
- [MultiSendCallOnly v1.3.0](#multisendcallonly-v130)
- [Safe v1.4.1](#safe-v141)
- [SafeL2 v1.4.1](#safel2-v141)
- [SafeProxyFactory v1.4.1](#safeproxyfactory-v141)
- [MultiSend v1.4.1](#multisend-v141)
- [MultiSendCallOnly v1.4.1](#multisendcallonly-v141)
- [Multicall3](#multicall3)
- [Create2Deployer](#create2deployer)
- [CreateX](#createx)
- [Arachnid's Deterministic Deployment Proxy](#arachnids-deterministic-deployment-proxy)
- [Zoltu's Deterministic Deployment Proxy](#zoltus-deterministic-deployment-proxy)
- [ERC-2470: Singleton Factory](#erc-2470-singleton-factory)
- [ERC-1820: Pseudo-introspection Registry Contract](#erc-1820-pseudo-introspection-registry-contract)
- [Permit2](#permit2)
- [EAS SchemaRegistry v1.4.0](#eas-schemaregistry-v140)
- [EAS v1.4.0](#eas-v140)
- [ERC-4337 EntryPoint v0.6.0](#erc-4337-entrypoint-v060)
- [ERC-4337 SenderCreator v0.6.0](#erc-4337-sendercreator-v060)
- [ERC-4337 EntryPoint v0.7.0](#erc-4337-entrypoint-v070)
- [ERC-4337 SenderCreator v0.7.0](#erc-4337-sendercreator-v070)
- [ERC-4337 EntryPoint v0.8.0](#erc-4337-entrypoint-v080)
- [ERC-4337 SenderCreator v0.8.0](#erc-4337-sendercreator-v080)
- [ERC-4337 Safe Module Setup v0.3.0](#erc-4337-safe-module-setup-v030)
- [ERC-4337 Safe 4337 Module v0.3.0 (for Entrypoint v0.7.0)](#erc-4337-safe-4337-module-v030-for-entrypoint-v070)
- [Kernel v3.3 (for Entrypoint v0.7.0)](#kernel-v33-for-entrypoint-v070)
- [KernelFactory v3.3 (for Entrypoing v0.7.0)](#kernelfactory-v33-for-entrypoing-v070)
- [MetaFactory (FactoryStaker) v3.0](#metafactory-factorystaker-v30)
- [ECDSAValidator v3.1 (commit 8f7fd99)](#ecdsavalidator-v31-commit-8f7fd99)

### SafeSingletonFactory v1.0.43

Deployed at `0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7` using CREATE from the address `0xE1CB04A0fA36DdD16a06ea828007E35e1a3cBC37` and nonce 0.

Source code available at https://github.com/safe-global/safe-singleton-factory/blob/v1.0.43/source/deterministic-deployment-proxy.yul .

This contract is a replica of Arachnid's Deterministic Deployment Proxy, that is deployed using a key controlled by the Safe team.

To deploy this contract, we need to act as the deployer address and deploy the creation bytecode.

#### How to verify the creation bytecode and the target address

This contract is compiled with a very old version of solc. To obtain the bytecode, run the following command:

```
docker run -v .:/sources --rm ethereum/solc:0.5.8 --strict-assembly /sources/source/deterministic-deployment-proxy.yul --optimize-yul
```

Bytecode:

```
0x604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3
```

Alternative, the runtime bytecode can be verified in any block explorer, for example, in [Arbiscan](https://arbiscan.io/address/0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7#code).

The target address can be verified in the project's [repository](https://github.com/safe-global/safe-singleton-factory/#expected-addresses).

### GnosisSafe v1.3.0

Deployed at `0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552` and `0x69f4D1788e39c87893C980c06EdF4b7f686e2938` using CREATE2.

Source code available at https://github.com/safe-global/safe-smart-account/blob/v1.3.0/contracts/GnosisSafe.sol .

Note: there are 2 addresses where this Safe can be deployed to:

- `0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552`: when using Arachnid's CREATE2 proxy (the canonical address)
- `0x69f4D1788e39c87893C980c06EdF4b7f686e2938`: when using the safe singleton factory

This script deploys the contract to both addresses.

#### How to verify the creation bytecode and the target address

Follow the building instructions of the repository and obtain the creation bytecode in the artifacts json file.

The target address can be verified in the [Safe deployments](https://github.com/safe-global/safe-deployments?tab=readme-ov-file#deployments-overview) repository.

### GnosisSafeL2 v1.3.0

Deployed at `0x3e5c63644e683549055b9be8653de26e0b4cd36e` and `0xfb1bffC9d739B8D520DaF37dF666da4C687191EA` using CREATE2.

Source code available at https://github.com/safe-global/safe-smart-account/blob/v1.3.0/contracts/GnosisSafeL2.sol .

Note: there are 2 addresses where this Safe can be deployed to:

- `0x3e5c63644e683549055b9be8653de26e0b4cd36e`: when using Arachnid's CREATE2 proxy (the canonical address)
- `0xfb1bffC9d739B8D520DaF37dF666da4C687191EA`: when using the safe singleton factory

This script deploys the contract to both addresses.

#### How to verify the creation bytecode and the target address

Follow the building instructions of the repository and obtain the creation bytecode in the artifacts json file.

The target address can be verified in the [Safe deployments](https://github.com/safe-global/safe-deployments?tab=readme-ov-file#deployments-overview) repository.

### GnosisSafeProxyFactory v1.3.0

Deployed at `0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2` and `0xC22834581EbC8527d974F8a1c97E1bEA4EF910BC` using CREATE2.

Source code available at https://github.com/safe-global/safe-smart-account/blob/v1.3.0/contracts/proxies/GnosisSafeProxyFactory.sol .

Note: there are 2 addresses where this Safe can be deployed to:

- `0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2`: when using Arachnid's CREATE2 proxy (the canonical address)
- `0xC22834581EbC8527d974F8a1c97E1bEA4EF910BC`: when using the safe singleton factory

This script deploys the contract to both addresses.

#### How to verify the creation bytecode and the target address

Follow the building instructions of the repository and obtain the creation bytecode in the artifacts json file.

The target address can be verified in the [Safe deployments](https://github.com/safe-global/safe-deployments?tab=readme-ov-file#deployments-overview) repository.

### MultiSend v1.3.0

Deployed at `0xa238cbeb142c10ef7ad8442c6d1f9e89e07e7761` and `0x998739BFdAAdde7C933B942a68053933098f9EDa` using CREATE2.

Source code available at https://github.com/safe-global/safe-smart-account/blob/v1.3.0/contracts/libraries/MultiSend.sol .

Note: there are 2 addresses where this contract can be deployed to:

- `0xa238cbeb142c10ef7ad8442c6d1f9e89e07e7761`: when using Arachnid's CREATE2 proxy (the canonical address)
- `0x998739BFdAAdde7C933B942a68053933098f9EDa`: when using the safe singleton factory

This script deploys the contract to both addresses.

#### How to verify the creation bytecode and the target address

Follow the building instructions of the repository and obtain the creation bytecode in the artifacts json file.

The target address can be verified in the [Safe deployments](https://github.com/safe-global/safe-deployments?tab=readme-ov-file#deployments-overview) repository.

### MultiSendCallOnly v1.3.0

Deployed at `0x40a2accbd92bca938b02010e17a5b8929b49130d` and `0xA1dabEF33b3B82c7814B6D82A79e50F4AC44102B` using CREATE2.

Source code available at https://github.com/safe-global/safe-smart-account/blob/v1.3.0/contracts/libraries/MultiSendCallOnly.sol .

Note: there are 2 addresses where this contract can be deployed to:

- `0x40a2accbd92bca938b02010e17a5b8929b49130d`: when using Arachnid's CREATE2 proxy (the canonical address)
- `0xA1dabEF33b3B82c7814B6D82A79e50F4AC44102B`: when using the safe singleton factory

This script deploys the contract to both addresses.

#### How to verify the creation bytecode and the target address

Follow the building instructions of the repository and obtain the creation bytecode in the artifacts json file.

The target address can be verified in the [Safe deployments](https://github.com/safe-global/safe-deployments?tab=readme-ov-file#deployments-overview) repository.

### Safe v1.4.1

Deployed at `0x41675C099F32341bf84BFc5382aF534df5C7461a` using CREATE2.

Source code available at https://github.com/safe-global/safe-smart-account/blob/v1.4.1/contracts/Safe.sol .

This contract is deployed using the Safe Singleton Factory.

#### How to verify the creation bytecode and the target address

Follow the building instructions of the repository and obtain the creation bytecode in the artifacts json file.

The target address can be verified in the [Safe deployments](https://github.com/safe-global/safe-deployments?tab=readme-ov-file#deployments-overview) repository.

### SafeL2 v1.4.1

Deployed at `0x29fcB43b46531BcA003ddC8FCB67FFE91900C762` using CREATE2.

Source code available at https://github.com/safe-global/safe-smart-account/blob/v1.4.1/contracts/SafeL2.sol .

This contract is deployed using the Safe Singleton Factory.

#### How to verify the creation bytecode and the target address

Follow the building instructions of the repository and obtain the creation bytecode in the artifacts json file.

The target address can be verified in the [Safe deployments](https://github.com/safe-global/safe-deployments?tab=readme-ov-file#deployments-overview) repository.

### SafeProxyFactory v1.4.1

Deployed at `0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67` using CREATE2.

Source code available at https://github.com/safe-global/safe-smart-account/blob/v1.4.1/contracts/proxies/SafeProxyFactory.sol .

This contract is deployed using the Safe Singleton Factory.

#### How to verify the creation bytecode and the target address

Follow the building instructions of the repository and obtain the creation bytecode in the artifacts json file.

The target address can be verified in the [Safe deployments](https://github.com/safe-global/safe-deployments?tab=readme-ov-file#deployments-overview) repository.

### MultiSend v1.4.1

Deployed at `0x38869bf66a61cF6bDB996A6aE40D5853Fd43B526` using CREATE2.

Source code available at https://github.com/safe-global/safe-smart-account/blob/v1.4.1/contracts/libraries/MultiSend.sol .

This contract is deployed using the Safe Singleton Factory.

#### How to verify the creation bytecode and the target address

Follow the building instructions of the repository and obtain the creation bytecode in the artifacts json file.

The target address can be verified in the [Safe deployments](https://github.com/safe-global/safe-deployments?tab=readme-ov-file#deployments-overview) repository.

### MultiSendCallOnly v1.4.1

Deployed at `0x9641d764fc13c8B624c04430C7356C1C7C8102e2` using CREATE2.

Source code available at https://github.com/safe-global/safe-smart-account/blob/v1.4.1/contracts/libraries/MultiSendCallOnly.sol .

This contract is deployed using the Safe Singleton Factory.

#### How to verify the creation bytecode and the target address

Follow the building instructions of the repository and obtain the creation bytecode in the artifacts json file.

The target address can be verified in the [Safe deployments](https://github.com/safe-global/safe-deployments?tab=readme-ov-file#deployments-overview) repository.

### Multicall3

Deployed at `0xcA11bde05977b3631167028862bE2a173976CA11` using a pre-signed transaction.

Source code available at https://github.com/mds1/multicall3/blob/v3.1.0/src/Multicall3.sol .

#### How to verify the pre-signed transaction, the runtime bytecode and the target address

The pre-signed transaction for this contract is available at [its repository](https://github.com/mds1/multicall3#new-deployments).

And the runtime bytecode can be verified by following the build instructions of the repository and obtaining the runtime bytecode in the artifacts json file.

Note that compiling the contract in the repository yields the same bytecode with the exception of the final IPFS metadata hash, which is different than the one that is deployed.

Alternative, the runtime bytecode can be verified in any block explorer, for example, in [Arbiscan](https://arbiscan.io/address/0xcA11bde05977b3631167028862bE2a173976CA11#code).

The target address can be verified in the project's [repository](https://github.com/mds1/multicall3/tree/v3.1.0#multicall3-contract-addresses).

### Create2Deployer

Deployed at `0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2` using CREATE from the address `0x554282Cf65b42fc8fddc6041eb24ce5E8A0632Ad` and nonce 0.

Source code available at https://github.com/pcaversaccio/create2deployer/blob/c7b353935fd9a55110e75fba93bad936db998957/contracts/Create2Deployer.sol .

To deploy this contract, we need to act as the deployer address and deploy the creation bytecode.

#### How to verify the creation bytecode and the target address

Follow the build instructions of the repository and obtain the creation bytecode in the artifacts json file.

Note: when comparing bytecodes with deployed instances, keep in mind that the contracts deployed on Ethereum, Arbitrum One, or OPStack chains are different. On Ethereum and Arbitrum One they are the deprecated versions of the contract. On OPStack chains, the version they use doesn't inherit from Ownable and Pausable. The pre-deployed contract used here is compiled with the latest version of the code, and can be verified with one of the recent deployments, for example the one on [Gravity](https://explorer.gravity.xyz/address/0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2).

The target address can be verified in the project's [repository](https://github.com/pcaversaccio/create2deployer/tree/c7b353935fd9a55110e75fba93bad936db998957#deployments-create2deployer).

### CreateX

Deployed at `0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed` using a pre-signed transaction.

Source code available at https://github.com/pcaversaccio/createx/blob/v1.0.0/src/CreateX.sol .

#### How to verify the pre-signed transaction, the runtime bytecode and the target address

The pre-signed transaction for this contract is available at [its repository](https://github.com/pcaversaccio/createx/blob/v1.0.0/scripts/presigned-createx-deployment-transactions/signed_serialised_transaction_gaslimit_3000000_.json).

And the runtime bytecode can be verified by following the build instructions of the repository and obtaining the runtime bytecode in the artifacts json file.

The target address can be verified in the project's [repository](https://github.com/pcaversaccio/createx/tree/v1.0.0#createx-deployments).

### Arachnid's Deterministic Deployment Proxy

Deployed at `0x4e59b44847b379578588920cA78FbF26c0B4956C` using a pre-signed transaction.

Source code available at https://github.com/Arachnid/deterministic-deployment-proxy/blob/99f24d0e09d8fad7ddb5cd37333e92a8956c9783/source/deterministic-deployment-proxy.yul .

This contract is already deployed on the local chain that Foundry creates to run their scripts. So the script verifies that the existing runtime bytecode is the expected one.

#### How to verify the runtime bytecode and the target address

This contract is compiled with a very old version of solc. To obtain the bytecode, run the following command:

```
docker run -v .:/sources --rm ethereum/solc:0.5.8 --strict-assembly /sources/src/deterministic-deployment-proxy.yul --optimize-yul
```

Bytecode:

```
0x604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3
```

Removing the creation component, `0x604580600e600039806000f350fe`, we are left with the runtime bytecode.

```
0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3
```

Alternative, the runtime bytecode can be verified in any block explorer, for example, in [Arbiscan](https://arbiscan.io/address/0x4e59b44847b379578588920cA78FbF26c0B4956C#code).

The target address can be verified in the project's [repository](https://github.com/Arachnid/deterministic-deployment-proxy/tree/99f24d0e09d8fad7ddb5cd37333e92a8956c9783#latest-outputs).

### Zoltu's Deterministic Deployment Proxy

Deployed at `0x7A0D94F55792C434d74a40883C6ed8545E406D12` using a pre-signed transaction.

Source code available at https://github.com/Zoltu/deterministic-deployment-proxy/blob/v1.0.0/source/deterministic-deployment-proxy.yul .

#### How to verify the pre-signed transaction, the runtime bytecode and the target address

This contract is compiled with a very old version of solc. To obtain the bytecode, run the following command:

```
docker run -v .:/sources --rm ethereum/solc:0.5.8 --strict-assembly /sources/src/deterministic-deployment-proxy.yul --optimize-yul
```

Bytecode:

```
0x601f80600e600039806000f350fe60003681823780368234f58015156014578182fd5b80825250506014600cf3
```

Removing the creation component, `0x601f80600e600039806000f350fe`, we are left with the runtime bytecode.

```
0x60003681823780368234f58015156014578182fd5b80825250506014600cf3
```

Alternative, the runtime bytecode can be verified in any block explorer, for example, in [Arbiscan](https://arbiscan.io/address/0x7A0D94F55792C434d74a40883C6ed8545E406D12#code).

The pre-signed transaction and the target address can be verified in the project's [repository](https://github.com/Zoltu/deterministic-deployment-proxy/blob/v1.0.0/README.md#latest-outputs).

### ERC-2470: Singleton Factory

Deployed at `0xce0042B868300000d44A59004Da54A005ffdcf9f` using a pre-signed transaction.

Source code available at https://eips.ethereum.org/EIPS/eip-2470#specification .

#### How to verify the pre-signed transaction, the runtime bytecode and the target address

The pre-signed transaction for this contract is available at [the EIP description](https://eips.ethereum.org/EIPS/eip-2470#deployment-transaction).

And the runtime bytecode can be verified in any block explorer, for example, in [Arbiscan](https://arbiscan.io/address/0xce0042B868300000d44A59004Da54A005ffdcf9f#code).

The target address can be verified in [the EIP description](https://eips.ethereum.org/EIPS/eip-2470#factory-contract-address).

### ERC-1820: Pseudo-introspection Registry Contract

Deployed at `0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24` using a pre-signed transaction.

Source code available at https://eips.ethereum.org/EIPS/eip-1820#specification .

#### How to verify the pre-signed transaction, the runtime bytecode and the target address

The pre-signed transaction for this contract is available at [the EIP description](https://eips.ethereum.org/EIPS/eip-1820#deployment-transaction).

And the runtime bytecode can be verified in any block explorer, for example, in [Arbiscan](https://arbiscan.io/address/0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24#code).

The target address can be verified in [the EIP description](https://eips.ethereum.org/EIPS/eip-1820#registry-contract-address).

### Permit2

Deployed at `0x000000000022D473030F116dDEE9F6B43aC78BA3` using CREATE2.

Source code available at https://github.com/Uniswap/permit2/blob/0x000000000022D473030F116dDEE9F6B43aC78BA3/src/Permit2.sol .

#### How to verify the creation bytecode and the target address

Follow the build instructions of the repository and obtain the creation bytecode in the artifacts json file.

The target address can be verified in the project's [repository](https://github.com/Uniswap/permit2/tree/0x000000000022D473030F116dDEE9F6B43aC78BA3) (the name of the branch is the expected address of the contract), and [Uniswap's documentation](https://docs.uniswap.org/contracts/v4/deployments).

### EAS SchemaRegistry v1.4.0

Deployed at `0x822B0B93BE3f3B8Da35a2E90e877C01215be8506` using CREATE2.

Source code available at https://github.com/ethereum-attestation-service/eas-contracts/blob/v1.4.0/contracts/SchemaRegistry.sol .

#### How to verify the creation bytecode

Follow the build instructions of the repository and obtain the creation bytecode in the artifacts json file.

Note that on-chain instances are deployed using CREATE, so the target address will likely be different. On-chain deployments of this contract can be found in EAS [repository](https://github.com/ethereum-attestation-service/eas-contracts#deployments).

### EAS v1.4.0

Deployed at `0xF4C9CCaf46A866e2c12C5Bd95A39694718044444` using CREATE2.

Source code available at https://github.com/ethereum-attestation-service/eas-contracts/blob/v1.4.0/contracts/EAS.sol .

#### How to verify the creation bytecode

Follow the build instructions of the repository and obtain the creation bytecode in the artifacts json file.

Note that on-chain instances are deployed using CREATE, so the target address will likely be different. On-chain deployments of this contract can be found in EAS [repository](https://github.com/ethereum-attestation-service/eas-contracts#deployments).

### ERC-4337 Entrypoint v0.6.0

Deployed at `0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789` using CREATE2.

Source code available at https://github.com/eth-infinitism/account-abstraction/blob/v0.6.0/contracts/core/EntryPoint.sol .

#### How to verify the creation bytecode and the target address

Follow the build instructions of the repository and obtain the creation bytecode in the artifacts json file.

The target address can be verified in the project's [repository](https://github.com/eth-infinitism/account-abstraction/tree/v0.6.0/deployments).

### ERC-4337 SenderCreator v0.6.0

Deployed at `0x7fc98430eAEdbb6070B35B39D798725049088348` while deploying Entrypoint v0.6.0.

Source code available at https://github.com/eth-infinitism/account-abstraction/blob/v0.6.0/contracts/core/SenderCreator.sol .

Since this contract is created when deploying the Entrypoint, we just verify that the runtime bytecode matches the expected one.

#### How to verify the runtime bytecode and the target address

Follow the build instructions of the repository and obtain the runtime bytecode in the artifacts json file.

Note: to match the obtained bytecode when compiling this contract, the `optimizedComilerSettings` in the `hardhat.config.ts` file must be used.

The target address can be verified in the project's [repository](https://github.com/eth-infinitism/account-abstraction/tree/v0.6.0/deployments).

### ERC-4337 Entrypoint v0.7.0

Deployed at `0x0000000071727De22E5E9d8BAf0edAc6f37da032` using CREATE2.

Source code available at https://github.com/eth-infinitism/account-abstraction/blob/v0.7.0/contracts/core/EntryPoint.sol .

#### How to verify the creation bytecode and the target address

Follow the build instructions of the repository and obtain the creation bytecode in the artifacts json file.

The target address can be verified in the project's [repository](https://github.com/eth-infinitism/account-abstraction/tree/v0.7.0/deployments).

### ERC-4337 SenderCreator v0.7.0

Deployed at `0xEFC2c1444eBCC4Db75e7613d20C6a62fF67A167C` while deploying Entrypoint v0.7.0.

Source code available at https://github.com/eth-infinitism/account-abstraction/blob/v0.7.0/contracts/core/SenderCreator.sol .

Since this contract is created when deploying the Entrypoint, we just verify that the runtime bytecode matches the expected one.

#### How to verify the runtime bytecode and the target address

Follow the build instructions of the repository and obtain the runtime bytecode in the artifacts json file.

Note: to match the obtained bytecode when compiling this contract, the `optimizedComilerSettings` in the `hardhat.config.ts` file must be used.

The target address can be verified in the project's [repository](https://github.com/eth-infinitism/account-abstraction/tree/v0.7.0/deployments).

### ERC-4337 Entrypoint v0.8.0

Deployed at `0x4337084d9e255ff0702461cf8895ce9e3b5ff108` using CREATE2.

Source code available at https://github.com/eth-infinitism/account-abstraction/blob/v0.8.0/contracts/core/EntryPoint.sol .

#### How to verify the creation bytecode and the target address

Follow the build instructions of the repository and obtain the creation bytecode in the artifacts json file.

The target address can be verified in the project's [repository](https://github.com/eth-infinitism/account-abstraction/tree/v0.8.0#entrypoint-deployment).

### ERC-4337 SenderCreator v0.8.0

Deployed at `0x449ED7C3e6Fee6a97311d4b55475DF59C44AdD33` while deploying Entrypoint v0.8.0.

Source code available at https://github.com/eth-infinitism/account-abstraction/blob/v0.8.0/contracts/core/SenderCreator.sol .

Since this contract is created when deploying the Entrypoint, we just verify that the runtime bytecode matches the expected one.

#### How to verify the runtime bytecode

Follow the build instructions of the repository and obtain the runtime bytecode in the artifacts json file.

Note that this contract contains an immutable variable set to the address of the Entrypoint. Thus, the runtime bytecode obtained after compilation will not exactly match. The immutable variable must be set to the right address before comparing it. Additionally, the final IPFS metadata hash obtained when compiling the contract will be different than the one deployed.

Alternative, the runtime bytecode can be verified in any block explorer, for example, in [Arbiscan](https://arbiscan.io/address/0x449ED7C3e6Fee6a97311d4b55475DF59C44AdD33#code).

### ERC-4337 Safe Module Setup v0.3.0

Deployed at `0x2dd68b007B46fBe91B9A7c3EDa5A7a1063cB5b47` using CREATE2.

Source code available at https://github.com/safe-global/safe-modules/blob/4337/v0.3.0/modules/4337/contracts/SafeModuleSetup.sol .

#### How to verify the creation bytecode and the target address

Follow the build instructions of the repository and obtain the creation bytecode in the artifacts json file.

The target address can be verified in the project's [repository](https://github.com/safe-global/safe-modules/blob/4337/v0.3.0/modules/4337/CHANGELOG.md#supported-entrypoint).

### ERC-4337 Safe 4337 Module v0.3.0 (for Entrypoint v0.7.0)

Deployed at `0x75cf11467937ce3F2f357CE24ffc3DBF8fD5c226` using CREATE2.

Source code available at https://github.com/safe-global/safe-modules/blob/4337/v0.3.0/modules/4337/contracts/Safe4337Module.sol .

Note that this contract must always be associated with a specific Entrypoint, set in the constructor. In this case, it's Entrypoint v0.7.0.

#### How to verify the creation bytecode and the target address

Follow the build instructions of the repository and obtain the creation bytecode in the artifacts json file.

The target address can be verified in the project's [repository](https://github.com/safe-global/safe-modules/blob/4337/v0.3.0/modules/4337/CHANGELOG.md#supported-entrypoint).

### Kernel v3.3 (for Entrypoint v0.7.0)

Deployed at `0xd6CEDDe84be40893d153Be9d467CD6aD37875b28` using CREATE2.

Source code available at https://github.com/zerodevapp/kernel/blob/v3.3/src/Kernel.sol .

Note that this contract must always be associated with a specific Entrypoint, set in the constructor. In this case, it's the Entrypoint v0.7.0.

#### How to verify the creation bytecode and the target address

Follow the build instructions of the repository and obtain the creation bytecode in the artifacts json file. Note that you must build the contracts using foundry with the profile `deploy`:

```shell
FOUNDRY_PROFILE=deploy forge build
```

The target address can be verified in the project's [repository](https://github.com/zerodevapp/kernel/#addresses).

### KernelFactory v3.3 (for Entrypoing v0.7.0)

Deployed at `0x2577507b78c2008Ff367261CB6285d44ba5eF2E9` using CREATE2.

Source code available at https://github.com/zerodevapp/kernel/blob/v3.3/src/factory/KernelFactory.sol .

Note that this contract must always be associated with a Kernel contract template that is associated with a specific Entrypoint, set in the constructor. In this case, it's the Entrypoint v0.7.0.

#### How to verify the creation bytecode and the target address

Follow the build instructions of the repository and obtain the creation bytecode in the artifacts json file. Note that you must build the contracts using foundry with the profile `deploy`:

```shell
FOUNDRY_PROFILE=deploy forge build
```

The target address can be verified in the project's [repository](https://github.com/zerodevapp/kernel/#addresses).

### MetaFactory (FactoryStaker) v3.0

Deployed at `0xd703aaE79538628d27099B8c4f621bE4CCd142d5` using CREATE2.

Source code available at https://github.com/zerodevapp/kernel/blob/v3.0/src/factory/FactoryStaker.sol .

#### How to verify the creation bytecode and the target address

Follow the build instructions of the repository and obtain the creation bytecode in the artifacts json file. Note that you must build the contracts using foundry with the following configuration:

```toml
via-ir = false
optimizer = true
runs = 200
solc_version = "0.8.24"
evm_version = "paris"
```

The target address can be verified in the project's [repository](https://github.com/zerodevapp/kernel/#addresses).

### ECDSAValidator v3.1 (commit 8f7fd99)

Deployed at `0x845ADb2C711129d4f3966735eD98a9F09fC4cE57` using CREATE2.

Source code available at https://github.com/zerodevapp/kernel/blob/8f7fd9946b9d351bb5be0428bf34c87bad7ed6c9/src/validator/ECDSAValidator.sol .

#### How to verify the creation bytecode and the target address

> [!NOTE]
> Even though the contract address is labelled as being the one for v3.1, it was actually compiled with a previous commit: `8f7fd9946b9d351bb5be0428bf34c87bad7ed6c9`. 

Follow the build instructions of the repository and obtain the creation bytecode in the artifacts json file. Note that you must build the contracts using foundry with the following configuration:

```toml
via-ir = true
optimizer = true
runs = 200
solc_version = "0.8.25"
evm_version = "paris"
```

The target address can be verified in the project's [repository](https://github.com/zerodevapp/kernel/#addresses).
