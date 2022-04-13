# ERC721LPDA 📉

ERC721LPDA is a ERC721A with last-price dutch auction feature built-in.

## Why?

Dutch auction is a great method for NTF projects to accomplish the price discovery. However, most of the "dutch auction" implementation in NFT drops have a negative effect on project's biggest fans as they trend to be the first group of users that ape into the dutch auction and end-up getting a NFT at a higher price than the others.

ERC721LPDA aims to solve this issue by changing the dutch auction machanism to everyone pays the final price. Whatever the auction ends at, users that paid higher than the last price can refund the overpaid amount. This will help the biggest fans of the project comfortably ape at the very beginning of the dutch auction as they know that everyone will get the same price in the end.

## Setup

To get started, clone the repo and install the developer dependencies:

```bash
git clone https://github.com/100x/ERC721LPDA.git
cd ERC721LPDA
yarn install # For prettier
git submodule update --init --recursive  # initialize submodule dependencies
```

## Compile & run the tests


```bash
forge build
forge test
```

## License

[MIT License](https://opensource.org/licenses/MIT)
