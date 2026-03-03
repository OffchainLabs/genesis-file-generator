// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {VmSafe} from "forge-std/Vm.sol";
import "forge-std/StdJson.sol";
import "script/Predeploys.s.sol";

contract GenerateGenesis is Script {
    using stdJson for string;

    // Type for alloc entries
    struct AllocEntry {
        uint256 balance;
        bytes code;
        uint256 nonce;
        mapping(bytes32 => bytes32) storageEntries;
    }

    /// @notice Output path for the generated JSON file
    string jsonOutPath = "genesis/genesis.json";

    /// @notice Initial environment variables
    bool isAnyTrust;
    uint256 arbOSVersion;
    address chainOwner;
    uint256 l1BaseFee;
    bool enableNativeTokenSupplyManagement;
    bool loadPredeploys;
    string customAllocFilePathStr;
    bool loadCustomAllocEntries;

    function setUp() public {
        // Load environment variables
        string memory isAnyTrustStr = vm.envString("IS_ANYTRUST");
        isAnyTrust = (keccak256(abi.encodePacked(isAnyTrustStr)) == keccak256(abi.encodePacked("true")));

        string memory arbOSVersionStr = vm.envString("ARBOS_VERSION");
        arbOSVersion = vm.parseUint(arbOSVersionStr);
        
        string memory chainOwnerStr = vm.envString("CHAIN_OWNER");
        chainOwner = vm.parseAddress(chainOwnerStr);
        
        string memory l1BaseFeeStr = vm.envString("L1_BASE_FEE");
        l1BaseFee = vm.parseUint(l1BaseFeeStr);
        
        string memory enableNativeTokenSupplyManagementStr = vm.envString("ENABLE_NATIVE_TOKEN_SUPPLY");
        enableNativeTokenSupplyManagement = (keccak256(abi.encodePacked(enableNativeTokenSupplyManagementStr)) == keccak256(abi.encodePacked("true")));
        
        string memory loadPredeploysStr = vm.envString("LOAD_DEFAULT_PREDEPLOYS");
        loadPredeploys = (keccak256(abi.encodePacked(loadPredeploysStr)) == keccak256(abi.encodePacked("true")));

        customAllocFilePathStr = vm.envString("CUSTOM_ALLOC_ACCOUNT_FILE");
        loadCustomAllocEntries = bytes(customAllocFilePathStr).length > 0;
    }

    function run() public {
        // Predeploys
        string memory genesisAllocJson;
        if (loadPredeploys) {
            Predeploys predeploys = new Predeploys();
            predeploys.setUp();
            genesisAllocJson = predeploys.run();
        } else {
            genesisAllocJson = "{}";
        }

        // Load additional alloc entries
        /*
        if (loadCustomAllocEntries) {
            // Load file
            string memory customAllocJson = vm.readFile(customAllocFilePathStr);

            // Get all addresses (keys)
            string[] memory contractAddresses = vm.parseJsonKeys(customAllocJson, "$");

            // Merge each entry into the genesisAllocJson
            for (uint256 i = 0; i < contractAddresses.length; i++) {
                console.log("Processing custom alloc entry for address:", contractAddresses[i]);
                string memory contractAddress = contractAddresses[i];
                bytes memory contractJson = vm.parseJson(customAllocJson, contractAddress);

                AllocEntry memory contractInformation = abi.decode(contractJson, (AllocEntry));

                if (i == contractAddresses.length - 1) {
                    genesisAllocJson = vm.serializeString(genesisAllocJson, contractAddress, vm.toString(contractJson));
                    break;
                } else {
                    vm.serializeString(genesisAllocJson, contractAddress, vm.toString(contractJson));
                }
            }
        } */

        // ArbOS init flags
        string memory genesisArbOSInit = "genesisArbOSInit";

        if (enableNativeTokenSupplyManagement) {
            vm.serializeBool(genesisArbOSInit, "nativeTokenSupplyManagementEnabled", true);
        }

        genesisArbOSInit = vm.serializeUint(genesisArbOSInit, "initialL1BaseFee", l1BaseFee);

        // Form the rest of the JSON structure
        string memory genesisJson = "genesisJson";
        uint256 chainId = block.chainid;
        vm.serializeString(
            genesisJson,
            "serializedChainConfig",
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
        vm.serializeString(genesisJson, "arbOSInit", genesisArbOSInit);
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
