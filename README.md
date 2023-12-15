# Uniswap V4 Violet Hooks
## **Uniswap v4 Hooks using the VioletID registry 🦄🟣**

This repository introduces an example showing how Violet's Identity and Compliance system can be used to add a permission layer on top of a Uniswap V4 pool, using Hooks.
It relies on the VioletID registry, which contains a mapping from an address to the attributes/statuses associated with the entity registered with Violet controlling that address. To learn more about it, please see [this page](https://docs.violet.co/for-developers/core-concepts/violetid-registry) from Violet's docs.

The VioletID registry is live on Ethereum Mainnet at [0xfFcDa323597A90af8F7A0eCBE4ef14e9b30e4a9e](https://etherscan.io/address/0xfFcDa323597A90af8F7A0eCBE4ef14e9b30e4a9e).

As shown in [`VioletHooksExample`](src/VioletHooksExample.sol), specific checks can be set for each pool such that:
- Only addresses with specific status(es) can interact with a pool
- And/or only addresses without specific status(es) can interact with a pool

When a hook is called, the Hooks contract in turn calls the VioletID registry and compare the VioletID statuses of the user against the requirements set for the pool involved in the transaction.

### Accessing the user's address from the hooks

Although the first field received as parameter in a V4 hook is an address called `sender`, this address might not correspond to the user's address, the one that ultimately should be checked against the VioletID Registry. The reason being that the PoolManager will call the hook contract passing `msg.sender` (see [here](https://github.com/Uniswap/v4-core/blob/5fb47b1d659a4ca91b6077a94d56221e806d7c82/src/PoolManager.sol#L251) for a swap for example).
<br/>However, just like in V3, it is likely that the address calling the `PoolManager` is not the end user but likely another contract such as a `SwapRouter` which sits in between.
In order to get the end users address then, the tests uses an approach passing it as `hookData`.

`hookData` is arbitrary calldata that can be passed along when calling the `PoolManager`, therefore in order to guarantee a correct identity check, it shifts the responsibility to the router contract to ensure that the end user's address initiating the interaction with a pool is correctly set as part of `hookData`. This is done in [`test/utils/routers`](test/utils/routers).
<br/>If a router contract doesn't correctly set the end user's address in hookData, but for example a hardcoded address of a fully compliant entity instead, this would circumvent the checks defined in the hooks - they will always pass regardless of the address which initiated the transaction. Therefore, the Hooks contract example here (`VioletHooksExample`) also contains logic to whitelist router contracts (received as sender in hooks).


---

### Local Development (Anvil)

*requires [foundry](https://book.getfoundry.sh)*

```
forge install
forge test
```

Because v4 exceeds the bytecode limit of Ethereum and it's *business licensed*, we can only deploy & test hooks on [anvil](https://book.getfoundry.sh/anvil/).

```bash
# start anvil, with a larger code limit
anvil --code-size-limit 30000

# in a new terminal
forge script script/Counter.s.sol \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --code-size-limit 30000 \
    --broadcast
```

---

## Troubleshooting


### *Permission Denied*

When installing dependencies with `forge install`, Github may throw a `Permission Denied` error

Typically caused by missing Github SSH keys, and can be resolved by following the steps [here](https://docs.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh)

Or [adding the keys to your ssh-agent](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent#adding-your-ssh-key-to-the-ssh-agent), if you have already uploaded SSH keys

### Hook deployment failures

Hook deployment failures are caused by incorrect flags or incorrect salt mining

1. Verify the flags are in agreement:
    * `getHookCalls()` returns the correct flags
    * `flags` provided to `HookMiner.find(...)`
    * In obscure cases where you're deploying multiple hooks (with the same flags), try setting `seed=1000` for ` HookMiner.find`
2. Verify salt mining is correct:
    * In **forge test**: the *deploye*r for: `new Hook{salt: salt}(...)` and `HookMiner.find(deployer, ...)` are the same. This will be `address(this)`. If using `vm.prank`, the deployer will be the pranking address
    * In **forge script**: the deployer must be the CREATE2 Proxy: `0x4e59b44847b379578588920cA78FbF26c0B4956C`
        * If anvil does not have the CREATE2 deployer, your foundry may be out of date. You can update it with `foundryup`

---

Additional resources:

[v4-periphery](https://github.com/uniswap/v4-periphery) contains advanced hook implementations that serve as a great reference

[v4-core](https://github.com/uniswap/v4-core)
