#!/usr/bin/env node

import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ENTRYPOINT_DIR = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = resolveProjectRoot(ENTRYPOINT_DIR);
const GENESIS_FILE_PATH = path.join(PROJECT_ROOT, 'genesis', 'genesis.json');
const REQUIRED_ENV_VARS = [
  'CHAIN_ID',
  'L1_BASE_FEE',
  'NITRO_NODE_IMAGE',
  'CHAIN_OWNER',
  'ARBOS_VERSION',
] as const;

type RequiredEnvVar = (typeof REQUIRED_ENV_VARS)[number];
type RequiredEnv = NodeJS.ProcessEnv & Record<RequiredEnvVar, string>;

const HELP_TEXT = `Usage: pnpm generate [OPTIONS]

Generate a genesis.json file for an Arbitrum chain with pre-deployed contracts.

Options:
  --help, -h                         Show this help message

Environment variables (set in .env file):
  CHAIN_ID                           Chain ID for the new chain
  IS_ANYTRUST                        Whether it's an Anytrust chain (true/false)
  ARBOS_VERSION                      ArbOS version to use
  CHAIN_OWNER                        Chain owner address
  L1_BASE_FEE                        Initial L1 base fee
  ENABLE_NATIVE_TOKEN_SUPPLY         Enable native token supply management in ArbOS (true/false)
  ENABLE_TRANSACTION_FILTERING       Enable transaction filtering in ArbOS (true/false)
  NITRO_NODE_IMAGE                   Nitro node Docker image
  LOAD_DEFAULT_PREDEPLOYS            Include default predeploys in the genesis file (true/false)
  CUSTOM_ALLOC_ACCOUNT_FILE          Path to custom alloc account file for additional predeploys (optional)
`;

try {
  main();
} catch (error) {
  process.stderr.write(`Error: ${error instanceof Error ? error.message : String(error)}\n`);
  process.exit(1);
}

function main(): void {
  if (process.argv.includes('--help') || process.argv.includes('-h')) {
    printHelp();
    return;
  }

  ensureRequiredEnv(process.env);

  // Ensure forge is installed
  try {
    execFileSync('forge', ['--version']);
  } catch {
    throw new Error(`forge is required to run this script.`);
  }

  mkdirSync(path.dirname(GENESIS_FILE_PATH), { recursive: true });

  execFileSync('forge', [
    'script',
    'script/GenerateGenesis.s.sol:GenerateGenesis',
    '--root',
    PROJECT_ROOT,
    '--chain-id',
    process.env.CHAIN_ID,
  ]);

  const genesis = JSON.parse(readFileSync(GENESIS_FILE_PATH, 'utf8'));

  if (process.env.CUSTOM_ALLOC_ACCOUNT_FILE) {
    const customAllocPath = path.resolve(process.cwd(), process.env.CUSTOM_ALLOC_ACCOUNT_FILE);
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

  const output = JSON.stringify(genesis);
  writeFileSync(GENESIS_FILE_PATH, output, 'utf8');

  process.stdout.write(`${output}\n`);
}

function printHelp(): void {
  process.stdout.write(HELP_TEXT);
}

function ensureRequiredEnv(env: NodeJS.ProcessEnv): asserts env is RequiredEnv {
  const missing = REQUIRED_ENV_VARS.filter((key) => !env[key]);
  if (missing.length > 0) {
    throw new Error(
      `Environment variables are not set in .env. You need to set at least ${missing.join(', ')}`,
    );
  }
}

function resolveProjectRoot(startDir: string): string {
  let currentDir = startDir;

  while (true) {
    const foundryConfigPath = path.join(currentDir, 'foundry.toml');
    const generateScriptPath = path.join(currentDir, 'script', 'GenerateGenesis.s.sol');

    if (existsSync(foundryConfigPath) && existsSync(generateScriptPath)) {
      return currentDir;
    }

    const parentDir = path.dirname(currentDir);
    if (parentDir === currentDir) {
      throw new Error(`Unable to locate the project root from ${startDir}`);
    }

    currentDir = parentDir;
  }
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
