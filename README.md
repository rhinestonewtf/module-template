## Module Template

**A template for building smart account modules using the [ModuleKit][https://github.com/rhinestonewtf/modulekit]**

## Usage

### Install dependencies

```shell
forge install
```

### Update dependencies

```shell
git submodule update --remote
```

### Building modules

1. Create a new file in `src/[MODULE_TYPE]` and inherit from the appropriate interface (see templates)
2. After you finished writing your module, run the following command:

```shell
forge build
```

### Testing modules

1. Create a new `.t.sol` file in `test/[MODULE_TYPE]` and inherit from the right account kit (see templates)
2. After you finished writing your tests, run the following command:

```shell
forge test
```

### Deploying modules

1. Create a new `.s.sol` file in `script/` and inherit from `Script` and `RegistryDeployer` (see templates).
2. Create a `.env` file in the root directory and add the following variables:

```shell
PK=[YOUR_PRIVATE_KEY]
```

3. Replace the variables enclosed in `[]` below and then run the command (ensure that you have the native token to pay for deployment gas):

```shell
forge script script/[SCRIPT_NAME].s.sol:[CONTRACT_NAME] --rpc-url [RPC_URL] --sender [SENDER_ADDRESS] --broadcast
```

## Tutorials

For a guided walkthrough of building a module, check out our [tutorials page](https://docs.rhinestone.wtf/tutorials). For a quickstart guide, head to [quickstart](https://docs.rhinestone.wtf/quickstart).
