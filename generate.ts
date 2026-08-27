#!/usr/bin/env node

import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ENTRYPOINT_DIR = path.dirname(fileURLToPath(import.meta.url));
const PACKAGE_ROOT =
  path.basename(ENTRYPOINT_DIR) === 'dist' ? path.dirname(ENTRYPOINT_DIR) : ENTRYPOINT_DIR;
const REQUIRED_ENV_VARS = [
  'CHAIN_ID',
  'L1_BASE_FEE',
  'NITRO_NODE_IMAGE',
  'CHAIN_OWNER',
  'ARBOS_VERSION',
  'MAX_CODE_SIZE',
  'MAX_INIT_CODE_SIZE',
] as const;

const DEFAULT_ENV_VARS = {
  IS_ANYTRUST: 'false',
  LOAD_DEFAULT_PREDEPLOYS: 'false',
  ENABLE_NATIVE_TOKEN_SUPPLY: 'false',
  ENABLE_TRANSACTION_FILTERING: 'false',
} as const;

type RequiredEnvVar = (typeof REQUIRED_ENV_VARS)[number];
type RequiredEnv = NodeJS.ProcessEnv & Record<RequiredEnvVar, string>;
type Genesis = Record<string, unknown>;

export type GenerateGenesisOptions = {
  chainId: string;
  isAnyTrust?: string;
  arbosVersion: string;
  chainOwner: string;
  maxCodeSize: string;
  maxInitCodeSize: string;
  l1BaseFee: string;
  nitroNodeImage: string;
  loadDefaultPredeploys?: string;
  enableNativeTokenSupply?: string;
  enableTransactionFiltering?: string;
  customAllocAccountFile?: string;
};

const HELP_TEXT = `Usage: pnpm generate [OPTIONS]

Generate a genesis.json file for an Arbitrum chain with pre-deployed contracts.

Options:
  --help, -h                         Show this help message

Environment variables (set in .env file):
  CHAIN_ID                           Chain ID for the new chain
  IS_ANYTRUST                        Whether it's an Anytrust chain (true/false)
  ARBOS_VERSION                      ArbOS version to use
  CHAIN_OWNER                        Chain owner address
  MAX_CODE_SIZE                      Maximum deployed contract code size
  MAX_INIT_CODE_SIZE                 Maximum contract initialization code size
  L1_BASE_FEE                        Initial L1 base fee
  ENABLE_NATIVE_TOKEN_SUPPLY         Enable native token supply management in ArbOS (true/false)
  ENABLE_TRANSACTION_FILTERING       Enable transaction filtering in ArbOS (true/false)
  NITRO_NODE_IMAGE                   Nitro node Docker image
  LOAD_DEFAULT_PREDEPLOYS            Include default predeploys in the genesis file (true/false)
  CUSTOM_ALLOC_ACCOUNT_FILE          Path to custom alloc account file for additional predeploys (optional)
`;

if (import.meta.main) {
  try {
    if (process.argv.includes('--help') || process.argv.includes('-h')) {
      printHelp();
      process.exit(0);
    }

    runGenesisGeneration(process.env);
  } catch (error) {
    process.stderr.write(`Error: ${error instanceof Error ? error.message : String(error)}\n`);
    process.exit(1);
  }
}

export function generateGenesis(options: GenerateGenesisOptions): Genesis {
  const env = {
    ...process.env,
    CHAIN_ID: options.chainId,
    IS_ANYTRUST: options.isAnyTrust,
    ARBOS_VERSION: options.arbosVersion,
    CHAIN_OWNER: options.chainOwner,
    MAX_CODE_SIZE: options.maxCodeSize,
    MAX_INIT_CODE_SIZE: options.maxInitCodeSize,
    L1_BASE_FEE: options.l1BaseFee,
    NITRO_NODE_IMAGE: options.nitroNodeImage,
    LOAD_DEFAULT_PREDEPLOYS: options.loadDefaultPredeploys,
    ENABLE_NATIVE_TOKEN_SUPPLY: options.enableNativeTokenSupply,
    ENABLE_TRANSACTION_FILTERING: options.enableTransactionFiltering,
    CUSTOM_ALLOC_ACCOUNT_FILE: options.customAllocAccountFile ?? '',
  };

  return runGenesisGeneration(env);
}

function runGenesisGeneration(env: NodeJS.ProcessEnv): Genesis {
  const resolvedEnv = withDefaultEnvVars(env);
  ensureRequiredEnv(resolvedEnv);
  const genesisFilePath = path.join(PACKAGE_ROOT, 'genesis', 'genesis.json');

  // Ensure forge is installed
  try {
    execFileSync('forge', ['--version']);
  } catch {
    throw new Error(`forge is required to run this script.`);
  }

  mkdirSync(path.dirname(genesisFilePath), { recursive: true });

  execFileSync(
    'forge',
    [
      'script',
      'script/GenerateGenesis.s.sol:GenerateGenesis',
      '--quiet',
      '--chain-id',
      resolvedEnv.CHAIN_ID,
    ],
    {
      cwd: PACKAGE_ROOT,
      env: resolvedEnv,
    },
  );

  const genesis = JSON.parse(readFileSync(genesisFilePath, 'utf8'));

  if (resolvedEnv.CUSTOM_ALLOC_ACCOUNT_FILE) {
    const customAllocPath = path.resolve(process.cwd(), resolvedEnv.CUSTOM_ALLOC_ACCOUNT_FILE);
    if (!existsSync(customAllocPath)) {
      throw new Error(`Custom alloc account file was specified, but not found: ${customAllocPath}`);
    }

    const customAlloc = JSON.parse(readFileSync(customAllocPath, 'utf8'));
    if (!isObject(customAlloc)) {
      throw new Error('Custom alloc account file must contain a JSON object.');
    }

    genesis.alloc = {
      ...(isObject(genesis.alloc) ? genesis.alloc : {}),
      ...customAlloc,
    };
  }

  genesis.serializedChainConfig =
    typeof genesis.serializedChainConfig === 'string'
      ? JSON.stringify(JSON.parse(genesis.serializedChainConfig))
      : JSON.stringify(genesis.serializedChainConfig);

  writeFileSync(genesisFilePath, `${JSON.stringify(genesis, null, 2)}\n`, 'utf8');

  return genesis;
}

function printHelp(): void {
  process.stdout.write(HELP_TEXT);
}

function withDefaultEnvVars(env: NodeJS.ProcessEnv): NodeJS.ProcessEnv {
  return {
    ...env,
    IS_ANYTRUST: env.IS_ANYTRUST || DEFAULT_ENV_VARS.IS_ANYTRUST,
    LOAD_DEFAULT_PREDEPLOYS:
      env.LOAD_DEFAULT_PREDEPLOYS || DEFAULT_ENV_VARS.LOAD_DEFAULT_PREDEPLOYS,
    ENABLE_NATIVE_TOKEN_SUPPLY:
      env.ENABLE_NATIVE_TOKEN_SUPPLY || DEFAULT_ENV_VARS.ENABLE_NATIVE_TOKEN_SUPPLY,
    ENABLE_TRANSACTION_FILTERING:
      env.ENABLE_TRANSACTION_FILTERING || DEFAULT_ENV_VARS.ENABLE_TRANSACTION_FILTERING,
  };
}

function ensureRequiredEnv(env: NodeJS.ProcessEnv): asserts env is RequiredEnv {
  const missing = REQUIRED_ENV_VARS.filter((key) => !env[key]);
  if (missing.length > 0) {
    throw new Error(
      `Environment variables are not set in .env. You need to set at least ${missing.join(', ')}`,
    );
  }
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
