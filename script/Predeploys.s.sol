// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {VmSafe} from "forge-std/Vm.sol";
import "forge-std/StdJson.sol";
import "src/PredeployConstants.sol";

contract Predeploys is Script {
    using stdJson for string;

    /// @notice Main deployer account (for CREATE2 deployments)
    address deployer = makeAddr("deployer");

    /// @notice Output path for the generated JSON file
    string jsonOutPath = "genesis/genesis.json";

    /// @notice Initial environment variables
    bool isAnyTrust;
    uint256 arbOSVersion;
    address chainOwner;

    function setUp() public {
        // Load environment variables
        string memory isAnyTrustStr = vm.envString("IS_ANYTRUST");
        isAnyTrust = (keccak256(abi.encodePacked(isAnyTrustStr)) == keccak256(abi.encodePacked("true")));
        string memory arbOSVersionStr = vm.envString("ARB_OS_VERSION");
        arbOSVersion = vm.parseUint(arbOSVersionStr);
        string memory chainOwnerStr = vm.envString("CHAIN_OWNER");
        chainOwner = vm.parseAddress(chainOwnerStr);

        // Deal funds to deployer accounts
        vm.deal(deployer, 1 ether);
        vm.deal(Multicall3DeployerAddress, 1 ether);
        vm.deal(CreateXDeployerAddress, 1 ether);
        vm.deal(ArachnidsDeployerAddress, 1 ether);
    }

    /// @notice Adds predeploy information to a JSON object
    /// @param predeployAddress The address of the predeploy
    /// @param code The runtime bytecode of the predeploy
    /// @param storageSlots The storage slots that were written during deployment
    /// @return predeployJson The JSON object as a string
    function addPredeployInformationToJson(address predeployAddress, bytes memory code, bytes32[] memory storageSlots)
        public
        returns (string memory)
    {
        string memory predeployJson = string.concat("predeployJson", vm.toString(predeployAddress));
        vm.serializeUint(predeployJson, "balance", predeployAddress.balance);
        vm.serializeUint(predeployJson, "nonce", vm.getNonce(predeployAddress));
        vm.serializeBytes(predeployJson, "code", code);

        // Storage changes
        string memory predeployStorageJson = string.concat("predeployStorageJson", vm.toString(predeployAddress));
        if (storageSlots.length > 0) {
            for (uint256 i = 0; i < storageSlots.length; i++) {
                bytes32 value = vm.load(predeployAddress, storageSlots[i]);
                vm.serializeBytes32(predeployStorageJson, vm.toString(storageSlots[i]), value);
            }

            // Last entry, we obtain the json object
            predeployStorageJson = vm.serializeBytes32(
                predeployStorageJson,
                vm.toString(storageSlots[storageSlots.length - 1]),
                vm.load(predeployAddress, storageSlots[storageSlots.length - 1])
            );
        } else {
            predeployStorageJson = "{}";
        }
        predeployJson = vm.serializeString(predeployJson, "storage", predeployStorageJson);

        return predeployJson;
    }

    /// @notice Deploys a contract's bytecode using CREATE
    /// @param bytecode The bytecode to deploy
    /// @param contractDeployer The address that will deploy the contract
    /// @param expectedAddr The expected address of the deployed contract
    /// @return code The runtime bytecode of the deployed contract
    /// @return writeSlots The storage slots that were written during deployment
    function deployContractViaCreate(bytes memory bytecode, address contractDeployer, address expectedAddr)
        public
        returns (bytes memory code, bytes32[] memory writeSlots)
    {
        address addr;
        vm.record();
        vm.broadcast(contractDeployer);
        assembly {
            addr := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        vm.stopRecord();

        // Verify that the contract was deployed
        require(addr != address(0), "Deployment failed");

        // Verify that the contract was deployed to the expected address
        require(addr == expectedAddr, "Contract deployed to incorrect address");

        // Return the runtime bytecode of the deployed contract and the written storage slots
        code = expectedAddr.code;
        (, writeSlots) = vm.accesses(expectedAddr);
    }

    /// @notice Deploys a contract's bytecode using CREATE2
    /// @param bytecode The bytecode to deploy
    /// @param salt The salt to use for CREATE2
    /// @param expectedAddr The expected address of the deployed contract
    /// @return code The runtime bytecode of the deployed contract
    /// @return writeSlots The storage slots that were written during deployment
    function deployContractViaCreate2(bytes memory bytecode, bytes32 salt, address expectedAddr)
        public
        returns (bytes memory code, bytes32[] memory writeSlots)
    {
        return deployContractViaCreate2(bytecode, salt, expectedAddr, ArachnidsAddress);
        /*
        address addr;
        vm.record();
        vm.broadcast();
        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        vm.stopRecord();

        // Verify that the contract was deployed
        require(addr != address(0), "CREATE2 failed");

        // Verify that the contract was deployed to the expected address
        require(addr == expectedAddr, "Contract deployed to incorrect address");

        // Return the runtime bytecode of the deployed contract and the written storage slots
        code = expectedAddr.code;
        (, writeSlots) = vm.accesses(expectedAddr);
        */
    }

    /// @notice Deploys a contract's bytecode using CREATE2
    /// @param bytecode The bytecode to deploy
    /// @param salt The salt to use for CREATE2
    /// @param expectedAddr The expected address of the deployed contract
    /// @return code The runtime bytecode of the deployed contract
    /// @return writeSlots The storage slots that were written during deployment
    function deployContractViaCreate2(bytes memory bytecode, bytes32 salt, address expectedAddr, address proxyAddress)
        public
        returns (bytes memory code, bytes32[] memory writeSlots)
    {
        vm.record();
        vm.broadcast();
        bytes memory callData = abi.encodePacked(salt, bytecode);
        (bool success, bytes memory result) = proxyAddress.call(callData);
        vm.stopRecord();

        // Verify that the call to the proxy was successful
        require(success, "CREATE2 proxy call failed");

        address addr = address(bytes20(result));

        // Verify that the contract was deployed
        require(addr != address(0), "CREATE2 failed");

        // Verify that the contract was deployed to the expected address
        require(addr == expectedAddr, "Contract deployed to incorrect address");

        // Return the runtime bytecode of the deployed contract and the written storage slots
        code = expectedAddr.code;
        (, writeSlots) = vm.accesses(expectedAddr);
    }

    /// @notice Deploys a contract using a signed transaction
    /// @param txData The signed transaction data
    /// @param expectedAddr The expected address of the deployed contract
    /// @return code The runtime bytecode of the deployed contract
    /// @return writeSlots The storage slots that were written during deployment
    function deployContractViaSignedTransaction(bytes memory txData, address expectedAddr)
        public
        returns (bytes memory code, bytes32[] memory writeSlots)
    {
        vm.record();
        vm.broadcastRawTransaction(txData);
        vm.stopRecord();

        // Verify that there's code at the expected address
        uint256 size;
        assembly {
            size := extcodesize(expectedAddr)
        }
        require(size > 0, "No code at the expected address");

        // Return the runtime bytecode of the deployed contract and the written storage slots
        code = expectedAddr.code;
        (, writeSlots) = vm.accesses(expectedAddr);
    }

    function run() public {
        // Initialize JSON output
        string memory genesisAllocJson = "genesisAllocJson";

        // -----------------------------------
        // Safe Singleton Factory (via CREATE)
        // -----------------------------------
        {
            console.log("Deploying Safe Singleton Factory");
            address contractAddress = SafeSingletonFactoryAddress;
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) = deployContractViaCreate(
                SafeSingletonFactoryCreationBytecode, SafeSingletonFactoryDeployerAddress, SafeSingletonFactoryAddress
            );
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // -----------------------------------
        // Safe v1.3 - canonical (via CREATE2)
        // -----------------------------------
        {
            console.log("Deploying Safe v1.3");
            address contractAddress = Safe1_3CanonicalAddress;
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) =
                deployContractViaCreate2(Safe1_3CreationBytecode, Safe1_3Salt, contractAddress);
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // -------------------------------------
        // SafeL2 v1.3 - canonical (via CREATE2)
        // -------------------------------------
        {
            console.log("Deploying SafeL2 v1.3");
            address contractAddress = SafeL21_3CanonicalAddress;
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) =
                deployContractViaCreate2(SafeL21_3CreationBytecode, SafeL21_3Salt, contractAddress);
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // ----------------------------------------
        // Multisend v1.3 - canonical (via CREATE2)
        // ----------------------------------------
        {
            console.log("Deploying Multisend v1.3");
            address contractAddress = Multisend1_3CanonicalAddress;
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) =
                deployContractViaCreate2(Multisend1_3CreationBytecode, Multisend1_3Salt, contractAddress);
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // ------------------------------------------------
        // MultisendCallOnly v1.3 - canonical (via CREATE2)
        // ------------------------------------------------
        {
            console.log("Deploying MultisendCallOnly v1.3");
            address contractAddress = MultisendCallOnly1_3CanonicalAddress;
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) = deployContractViaCreate2(
                MultisendCallOnly1_3CreationBytecode, MultisendCallOnly1_3Salt, contractAddress
            );
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // ---------------------------------
        // Safe v1.3 - EIP-155 (via CREATE2)
        // ---------------------------------
        {
            console.log("Deploying Safe v1.3 (EIP-155)");
            address contractAddress = Safe1_3Eip155Address;
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) = deployContractViaCreate2(
                Safe1_3CreationBytecode, Safe1_3Salt, contractAddress, SafeSingletonFactoryAddress
            );
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // -----------------------------------
        // SafeL2 v1.3 - EIP-155 (via CREATE2)
        // -----------------------------------
        {
            console.log("Deploying SafeL2 v1.3 (EIP-155)");
            address contractAddress = SafeL21_3Eip155Address;
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) = deployContractViaCreate2(
                SafeL21_3CreationBytecode, SafeL21_3Salt, contractAddress, SafeSingletonFactoryAddress
            );
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // --------------------------------------
        // Multisend v1.3 - EIP-155 (via CREATE2)
        // --------------------------------------
        {
            console.log("Deploying Multisend v1.3 (EIP-155)");
            address contractAddress = Multisend1_3Eip155Address;
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) = deployContractViaCreate2(
                Multisend1_3CreationBytecode, Multisend1_3Salt, contractAddress, SafeSingletonFactoryAddress
            );
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // ----------------------------------------------
        // MultisendCallOnly v1.3 - EIP-155 (via CREATE2)
        // ----------------------------------------------
        {
            console.log("Deploying MultisendCallOnly v1.3 (EIP-155)");
            address contractAddress = MultisendCallOnly1_3Eip155Address;
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) = deployContractViaCreate2(
                MultisendCallOnly1_3CreationBytecode,
                MultisendCallOnly1_3Salt,
                contractAddress,
                SafeSingletonFactoryAddress
            );
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // -------------------------------------
        // Safe v1.4.1 - canonical (via CREATE2)
        // -------------------------------------
        {
            console.log("Deploying Safe v1.4.1");
            address contractAddress = Safe1_4_1Address;
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) = deployContractViaCreate2(
                Safe1_4_1CreationBytecode, Safe1_4_1Salt, Safe1_4_1Address, SafeSingletonFactoryAddress
            );
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // ---------------------------------------
        // SafeL2 v1.4.1 - canonical (via CREATE2)
        // ---------------------------------------
        {
            console.log("Deploying SafeL2 v1.4.1");
            address contractAddress = SafeL21_4_1Address;
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) = deployContractViaCreate2(
                SafeL21_4_1CreationBytecode, SafeL21_4_1Salt, SafeL21_4_1Address, SafeSingletonFactoryAddress
            );
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // ------------------------------------------
        // Multisend v1.4.1 - canonical (via CREATE2)
        // ------------------------------------------
        {
            console.log("Deploying Multisend v1.4.1");
            address contractAddress = Multisend1_4_1Address;
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) = deployContractViaCreate2(
                Multisend1_4_1CreationBytecode, Multisend1_4_1Salt, Multisend1_4_1Address, SafeSingletonFactoryAddress
            );
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // --------------------------------------------------
        // MultisendCallOnly v1.4.1 - canonical (via CREATE2)
        // --------------------------------------------------
        {
            console.log("Deploying MultisendCallOnly v1.4.1");
            address contractAddress = MultisendCallOnly1_4_1Address;
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) = deployContractViaCreate2(
                MultisendCallOnly1_4_1CreationBytecode,
                MultisendCallOnly1_4_1Salt,
                MultisendCallOnly1_4_1Address,
                SafeSingletonFactoryAddress
            );
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // -----------------------------------
        // Multicall3 (via signed transaction)
        // -----------------------------------
        {
            console.log("Deploying Multicall3");
            address contractAddress = MultiCall3Address;
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) =
                deployContractViaSignedTransaction(MultiCall3Tx, MultiCall3Address);
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // ------------------------------------------
        // Create2Deployer (via CREATE)
        // We also renounce ownership of the contract
        // ------------------------------------------
        {
            console.log("Deploying Create2Deployer");
            address contractAddress = Create2DeployerAddress;
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) = deployContractViaCreate(
                Create2DeployerCreationBytecode, Create2DeployerDeployerAddress, Create2DeployerAddress
            );

            // Renouncing ownership
            console.log("Renouncing ownership of Create2Deployer");
            vm.record();
            vm.broadcast(Create2DeployerDeployerAddress);
            (bool success,) = Create2DeployerAddress.call(abi.encodeWithSignature("renounceOwnership()"));
            vm.stopRecord();
            require(success, "Renouncing ownership failed");
            (, bytes32[] memory renounceWriteSlots) = vm.accesses(Create2DeployerAddress);

            // Merge write slots
            // Note: we don't really need to merge since the slot that is modified is the same,
            // but this is to keep the output consistent
            bytes32[] memory mergedWriteSlots = new bytes32[](contractWriteSlots.length + renounceWriteSlots.length);
            for (uint256 i = 0; i < contractWriteSlots.length; i++) {
                mergedWriteSlots[i] = contractWriteSlots[i];
            }
            for (uint256 j = 0; j < renounceWriteSlots.length; j++) {
                mergedWriteSlots[contractWriteSlots.length + j] = renounceWriteSlots[j];
            }

            console.log("Contract deployed at:", contractAddress);
            string memory contractJson = addPredeployInformationToJson(contractAddress, contractCode, mergedWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // --------------------------------
        // CreateX (via signed transaction)
        // --------------------------------
        {
            console.log("Deploying CreateX");
            address contractAddress = CreateXAddress;
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) =
                deployContractViaSignedTransaction(CreateXTx, CreateXAddress);
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // ------------------------------------------------------------
        // Arachnid's Deterministic Deployment Proxy (already deployed)
        // ------------------------------------------------------------
        // Note: By default, this proxy is already deployed in foundry's local chains
        //       We only check that the deployed bytecode matches the expected one
        {
            console.log("Checking Arachnid's Deterministic Deployment Proxy");
            address contractAddress = ArachnidsAddress;
            bytes memory contractCode = contractAddress.code;
            require(
                keccak256(contractCode) == keccak256(ArachnidsExpectedRuntimeBytecode),
                "Arachnid's Proxy bytecode mismatch"
            );
            bytes32[] memory contractWriteSlots = new bytes32[](0);
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // ---------------------
        // Permit2 (via CREATE2)
        // ---------------------
        {
            console.log("Deploying Permit2");
            address contractAddress = Permit2Address;
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) =
                deployContractViaCreate2(Permit2CreationBytecode, Permit2Salt, Permit2Address);
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // ---------------------------------------
        // EAS SchemaRegistry v1.4.0 (via CREATE2)
        // ---------------------------------------
        {
            console.log("Deploying EAS SchemaRegistry v1.4.0");
            address contractAddress = EASSchemaRegistryAddress;
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) = deployContractViaCreate2(
                EASSchemaRegistryCreationBytecode, EASSchemaRegistrySalt, EASSchemaRegistryAddress
            );
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // ------------------------
        // EAS v1.4.0 (via CREATE2)
        // ------------------------
        {
            console.log("Deploying EAS v1.4.0");
            address contractAddress = EASAddress;
            bytes memory easCreationBytecode = abi.encodePacked(
                EASCreationBytecode,
                abi.encode(EASSchemaRegistryAddress) // Constructor argument: SchemaRegistry address
            );
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) =
                deployContractViaCreate2(easCreationBytecode, EASSalt, EASAddress);
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // ----------------------------------------
        // ERC-4337 Entrypoint v0.6.0 (via CREATE2)
        // ----------------------------------------
        {
            console.log("Deploying ERC-4337 Entrypoint v0.6.0");
            address contractAddress = ERC4337_Entrypoint0_6_0Address;
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) = deployContractViaCreate2(
                ERC4337_Entrypoint0_6_0CreationBytecode, ERC4337_Entrypoint0_6_0Salt, ERC4337_Entrypoint0_6_0Address
            );
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // ------------------------------------------------
        // ERC-4337 SenderCreator v0.6.0 (already deployed)
        // ------------------------------------------------
        // Note: By default, this contract is created when deploying the Entrypoint
        //       We only check that the deployed bytecode matches the expected one
        {
            console.log("Checking ERC-4337 SenderCreator v0.6.0");
            address contractAddress = ERC4337_SenderCreator0_6_0Address;
            bytes memory contractCode = contractAddress.code;
            require(
                keccak256(contractCode) == keccak256(ERC4337_SenderCreator0_6_0ExpectedRuntimeBytecode),
                "ERC-4337 SenderCreator bytecode mismatch"
            );
            bytes32[] memory contractWriteSlots = new bytes32[](0);
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // ----------------------------------------
        // ERC-4337 Entrypoint v0.7.0 (via CREATE2)
        // ----------------------------------------
        {
            console.log("Deploying ERC-4337 Entrypoint v0.7.0");
            address contractAddress = ERC4337_Entrypoint0_7_0Address;
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) = deployContractViaCreate2(
                ERC4337_Entrypoint0_7_0CreationBytecode, ERC4337_Entrypoint0_7_0Salt, ERC4337_Entrypoint0_7_0Address
            );
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // ------------------------------------------------
        // ERC-4337 SenderCreator v0.7.0 (already deployed)
        // ------------------------------------------------
        // Note: By default, this contract is created when deploying the Entrypoint
        //       We only check that the deployed bytecode matches the expected one
        {
            console.log("Checking ERC-4337 SenderCreator v0.7.0");
            address contractAddress = ERC4337_SenderCreator0_7_0Address;
            bytes memory contractCode = contractAddress.code;
            require(
                keccak256(contractCode) == keccak256(ERC4337_SenderCreator0_7_0ExpectedRuntimeBytecode),
                "ERC-4337 SenderCreator bytecode mismatch"
            );
            bytes32[] memory contractWriteSlots = new bytes32[](0);
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // ----------------------------------------
        // ERC-4337 Entrypoint v0.8.0 (via CREATE2)
        // ----------------------------------------
        {
            console.log("Deploying ERC-4337 Entrypoint v0.8.0");
            address contractAddress = ERC4337_Entrypoint0_8_0Address;
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) = deployContractViaCreate2(
                ERC4337_Entrypoint0_8_0CreationBytecode, ERC4337_Entrypoint0_8_0Salt, ERC4337_Entrypoint0_8_0Address
            );
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // ------------------------------------------------
        // ERC-4337 SenderCreator v0.8.0 (already deployed)
        // ------------------------------------------------
        // Note: By default, this contract is created when deploying the Entrypoint
        //       We only check that the deployed bytecode matches the expected one
        {
            console.log("Checking ERC-4337 SenderCreator v0.8.0");
            address contractAddress = ERC4337_SenderCreator0_8_0Address;
            bytes memory contractCode = contractAddress.code;
            require(
                keccak256(contractCode) == keccak256(ERC4337_SenderCreator0_8_0ExpectedRuntimeBytecode),
                "ERC-4337 SenderCreator bytecode mismatch"
            );
            bytes32[] memory contractWriteSlots = new bytes32[](0);
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // -----------------------------------------------
        // ERC-4337 Safe Module Setup v0.3.0 (via CREATE2)
        // -----------------------------------------------
        {
            console.log("Deploying ERC-4337 Safe Module Setup v0.3.0");
            address contractAddress = SafeModuleSetup0_3_0Address;
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) = deployContractViaCreate2(
                SafeModuleSetup0_3_0CreationBytecode, SafeModuleSetup0_3_0Salt, SafeModuleSetup0_3_0Address
            );
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // -----------------------------------------------------------------------------
        // ERC-4337 Safe 4337 Module v0.3.0 (supporting Entrypoint v0.7.0) (via CREATE2)
        // -----------------------------------------------------------------------------
        {
            console.log("Deploying ERC-4337 Safe 4337 Module v0.3.0 (supporting Entrypoint v0.7.0)");
            address contractAddress = Safe4337Module0_3_0Entrypoint0_7_0Address;
            bytes memory safe4337ModuleEntrypoint0_7_0CreationBytecode = abi.encodePacked(
                Safe4337Module0_3_0Entrypoint0_7_0CreationBytecode,
                abi.encode(ERC4337_Entrypoint0_7_0Address) // Constructor argument: entrypoint address
            );
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) = deployContractViaCreate2(
                safe4337ModuleEntrypoint0_7_0CreationBytecode,
                Safe4337Module0_3_0Entrypoint0_7_0Salt,
                Safe4337Module0_3_0Entrypoint0_7_0Address
            );
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        //
        // Kernel v3.3 (supporting Entrypoint v0.7.0) (via CREATE2)
        // --------------------------------------------------------
        {
            console.log("Deploying Kernel v3.3 (supporting Entrypoint v0.7.0)");
            address contractAddress = Kernel_Entrypoint0_7_0Address;
            bytes memory kernel_Entrypoint0_7_0CreationBytecode = abi.encodePacked(
                Kernel_Entrypoint0_7_0CreationBytecode,
                abi.encode(ERC4337_Entrypoint0_7_0Address) // Constructor argument: entrypoint address
            );
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) = deployContractViaCreate2(
                kernel_Entrypoint0_7_0CreationBytecode, Kernel_Entrypoint0_7_0Salt, Kernel_Entrypoint0_7_0Address
            );
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // ---------------------------------------------------------------
        // KernelFactory v3.3 (supporting Entrypoint v0.7.0) (via CREATE2)
        // ---------------------------------------------------------------
        {
            console.log("Deploying KernelFactory v3.3 (supporting Entrypoint v0.7.0)");
            address contractAddress = KernelFactory_Entrypoint0_7_0Address;
            bytes memory kernelFactory_Entrypoint0_7_0CreationBytecode = abi.encodePacked(
                KernelFactory_Entrypoint0_7_0CreationBytecode,
                abi.encode(Kernel_Entrypoint0_7_0Address) // Constructor argument: entrypoint address
            );
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) = deployContractViaCreate2(
                kernelFactory_Entrypoint0_7_0CreationBytecode,
                KernelFactory_Entrypoint0_7_0Salt,
                KernelFactory_Entrypoint0_7_0Address
            );
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // ---------------------------------------
        // Kernel FactoryStaker v3.0 (via CREATE2)
        // ---------------------------------------
        {
            console.log("Deploying Kernel FactoryStaker v3.0");
            address contractAddress = KernelFactoryStakerAddress;
            bytes memory kernelFactoryStakerCreationBytecode = abi.encodePacked(
                KernelFactoryStakerCreationBytecode,
                abi.encode(KernelFactoryStakerOwnerAddress) // Constructor argument: owner of the factories
            );
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) = deployContractViaCreate2(
                kernelFactoryStakerCreationBytecode, KernelFactoryStakerSalt, KernelFactoryStakerAddress
            );
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // ----------------------------------------
        // Kernel ECDSAValidator v3.1 (via CREATE2)
        // ----------------------------------------
        {
            console.log("Deploying Kernel ECDSAValidator v3.1");
            address contractAddress = KernelECDSAValidatorAddress;
            (bytes memory contractCode, bytes32[] memory contractWriteSlots) = deployContractViaCreate2(
                KernelECDSAValidatorCreationBytecode, KernelECDSAValidatorSalt, KernelECDSAValidatorAddress
            );
            console.log("Contract deployed at:", contractAddress);
            string memory contractJson =
                addPredeployInformationToJson(contractAddress, contractCode, contractWriteSlots);
            genesisAllocJson = vm.serializeString(genesisAllocJson, vm.toString(contractAddress), contractJson);
        }

        // Form the rest of the JSON structure
        string memory genesisJson = "genesisJson";
        uint256 chainId = block.chainid;
        vm.serializeString(
            genesisJson,
            "config",
            string.concat(
                '{"chainId":',
                vm.toString(chainId),
                ',"homesteadBlock":0,"daoForkBlock":null,"daoForkSupport":true,"eip150Block":0,"eip150Hash":"0x0000000000000000000000000000000000000000000000000000000000000000","eip155Block":0,"eip158Block":0,"byzantiumBlock":0,"constantinopleBlock":0,"petersburgBlock":0,"istanbulBlock":0,"muirGlacierBlock":0,"berlinBlock":0,"londonBlock":0,"clique":{"period":0,"epoch":0},"arbitrum":{"EnableArbOS":true,"AllowDebugPrecompiles":false,"DataAvailabilityCommittee":',
                vm.toString(isAnyTrust),
                ',"InitialArbOSVersion":',
                vm.toString(arbOSVersion),
                ',"InitialChainOwner":"',
                vm.toString(chainOwner),
                '","GenesisBlockNum":0,"MaxCodeSize":24576,"MaxInitCodeSize":49152}}'
            )
        );
        vm.serializeString(genesisJson, "nonce", "0x0");
        vm.serializeString(genesisJson, "timestamp", "0x0");
        vm.serializeString(genesisJson, "extraData", "0x");
        vm.serializeString(genesisJson, "gasLimit", "0x1C9C380"); // 30,000,000
        vm.serializeString(genesisJson, "difficulty", "0x1");
        vm.serializeString(genesisJson, "mixHash", "0x0000000000000000000000000000000000000000000000000000000000000000");
        vm.serializeString(genesisJson, "coinbase", "0x0000000000000000000000000000000000000000");
        genesisJson = vm.serializeString(genesisJson, "alloc", genesisAllocJson);

        // Write the JSON output to file
        genesisJson.write(jsonOutPath);
        console.log("Wrote runtime bytecode to", jsonOutPath);
    }
}
