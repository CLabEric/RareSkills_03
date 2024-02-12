## Write a markdown file explaining how to use the TWAP oracle with Uniswap V2. You need to answer the following questions:

# Why does the `price0CumulativeLast` and `price1CumulativeLast` never decrement?

In the \_update() function we use a "+=" so the number only gets larger until it overflows. We just want the difference in price ratios from the last snapshot
so we can divide by the time elapsed. This method allows us to only store one previous value.

# How do you write a contract that uses the oracle?

We need to access three values: price0CumulativeLast, price1CumulativeLast and blockTimestampLast. We then need to grab these values again after whatever
timeframe we wish. The math is as follows:

p0CL --> initial value of price0CumulativeLast
p0CL' --> subsequent value of price0CumulativeLast

token0Price = (p0CL' - p0CL) / time elapsed
token1Price = (p1CL' - p1CL) / time elapsed

Note that if the cumulative values have not been updated, perhaps it was a slow period of trading, we can call sync() to update the values.

# Why are `price0CumulativeLast` and `price1CumulativeLast` stored separately? Why not just calculate ``price1CumulativeLast = 1/price0CumulativeLast`?

Because that math does not work. Consider the example:

token0Reserve is 200 and
token1Reserve is 100

Let's ignore time and rounding errors for now. The way we want to handle the price ratio is..
token0Price = 100/200 = 0.5
token1Price = 200/100 = 2

according to the formula above these calculations would be...
token0Price = 1/100 = 0.01 which does NOT equal 0.5
token1Price = 1/200 = 0.005 which does NOT equal 2
