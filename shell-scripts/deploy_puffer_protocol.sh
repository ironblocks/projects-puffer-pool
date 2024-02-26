# PK is for anvil #1 account and he is the deployer
export PK=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export RPC_URL="http://localhost:8545"
export DEV_WALLET=0xDDDeAfB492752FC64220ddB3E7C9f1d5CcCdFdF0
# Tell the deployment scripts that it is not `forge test` environment
export IS_LOCAL_ANVIL=true

#Change the MR_ENCLAVE and MR_SIGNER to the correct values
export MR_ENCLAVE=38263e1523af61fecf337417fd00d688db04ed62644c2348a6e0e98fac490dec
export MR_SIGNER=83d719e77deaca1470f6baf62a4d774303c899db69020f9c70ee1dfc08c7ce9e

# amount to fund the pool with
export ETH_AMOUNT="256ether"

echo "DEPLOYING"
forge script script/DeployEverything.s.sol:DeployEverything --rpc-url=$RPC_URL --sig 'run(address[] calldata, uint256)' "[$DEV_WALLET]" 1 --broadcast

echo "SETUP SetGuardianEnclaveMeasurements"
forge script script/SetGuardianEnclaveMeasurements.s.sol:SetEnclaveMeasurements --rpc-url=$RPC_URL --broadcast --sig "run(bytes32,bytes32)" -vvvv 0x${MR_ENCLAVE} 0x${MR_SIGNER}

echo "SETUP AddLeafX509"
forge script script/AddLeafX509.s.sol:AddLeaftX509 --rpc-url=$RPC_URL --broadcast --sig "run(bytes)" -vvvv 0x308204a130820309a003020102020900d107765d32a3b096300d06092a864886f70d01010b0500307e310b3009060355040613025553310b300906035504080c0243413114301206035504070c0b53616e746120436c617261311a3018060355040a0c11496e74656c20436f72706f726174696f6e3130302e06035504030c27496e74656c20534758204174746573746174696f6e205265706f7274205369676e696e67204341301e170d3136313132323039333635385a170d3236313132303039333635385a307b310b3009060355040613025553310b300906035504080c0243413114301206035504070c0b53616e746120436c617261311a3018060355040a0c11496e74656c20436f72706f726174696f6e312d302b06035504030c24496e74656c20534758204174746573746174696f6e205265706f7274205369676e696e6730820122300d06092a864886f70d01010105000382010f003082010a0282010100a97a2de0e66ea6147c9ee745ac0162686c7192099afc4b3f040fad6de093511d74e802f510d716038157dcaf84f4104bd3fed7e6b8f99c8817fd1ff5b9b864296c3d81fa8f1b729e02d21d72ffee4ced725efe74bea68fbc4d4244286fcdd4bf64406a439a15bcb4cf67754489c423972b4a80df5c2e7c5bc2dbaf2d42bb7b244f7c95bf92c75d3b33fc5410678a89589d1083da3acc459f2704cd99598c275e7c1878e00757e5bdb4e840226c11c0a17ff79c80b15c1ddb5af21cc2417061fbd2a2da819ed3b72b7efaa3bfebe2805c9b8ac19aa346512d484cfc81941e15f55881cc127e8f7aa12300cd5afb5742fa1d20cb467a5beb1c666cf76a368978b50203010001a381a43081a1301f0603551d2304183016801478437b76a67ebcd0af7e4237eb357c3b8701513c300e0603551d0f0101ff0404030206c0300c0603551d130101ff0402300030600603551d1f045930573055a053a051864f687474703a2f2f7472757374656473657276696365732e696e74656c2e636f6d2f636f6e74656e742f43524c2f5347582f4174746573746174696f6e5265706f72745369676e696e6743412e63726c300d06092a864886f70d01010b050003820181006708b61b5c2bd215473e2b46af99284fbb939d3f3b152c996f1a6af3b329bd220b1d3b610f6bce2e6753bded304db21912f385256216cfcba456bd96940be892f5690c260d1ef84f1606040222e5fe08e5326808212a447cfdd64a46e94bf29f6b4b9a721d25b3c4e2f62f58baed5d77c505248f0f801f9fbfb7fd752080095cee80938b339f6dbb4e165600e20e4a718812d49d9901e310a9b51d66c79909c6996599fae6d76a79ef145d9943bf1d3e35d3b42d1fb9a45cbe8ee334c166eee7d32fcdc9935db8ec8bb1d8eb3779dd8ab92b6e387f0147450f1e381d08581fb83df33b15e000a59be57ea94a3a52dc64bdaec959b3464c91e725bbdaea3d99e857e380a23c9d9fb1ef58e9e42d71f12130f9261d7234d6c37e2b03dba40dfdfb13ac4ad8e13fd3756356b6b50015a3ec9580b815d87c2cef715cd28df00bbf2a3c403ebf6691b3f05edd9143803ca085cff57e053eec2f8fea46ea778a68c9be885bc28225bc5f309be4a2b74d3a03945319dd3c7122fed6ff53bb8b8cb3a03c

# Send 32 ETH to PUFFER_SHARED_WALLET
cast send $DEV_WALLET --value 32ether --private-key $PK --rpc-url=$RPC_URL

echo "Deposit initial liquidity for PufferVault"
forge script script/DepositETH.s.sol:DepositETH --rpc-url=$RPC_URL --broadcast --sig "run(uint256)" $ETH_AMOUNT -vvvv --private-key $PK

echo "Saving ABIs"
mkdir -p anvil-ABIs
cp output/puffer.json anvil-ABIs/addresses.json
forge inspect PufferProtocol abi > anvil-ABIs/PufferProtocol.json
forge inspect GuardianModule abi > anvil-ABIs/GuardianModule.json
forge inspect PufferVaultV2 abi > anvil-ABIs/PufferVault.json
forge inspect ValidatorTicket abi > anvil-ABIs/ValidatorTicket.json
forge inspect PufferOracle abi > anvil-ABIs/PufferOracle.json
forge inspect NoRestakingModule abi > anvil-ABIs/NoRestakingModule.json