# UIComponents
> iOS UI helpers

Several classes simplifying implementation of UI in iOS apps.

## LoadingPresenter

UI helper that can present several types of loadings and errors during operation executing.

Create presenter specifying the view on which the loading or errors will be shown

```swift
let loadingPresenter = LoadingPresenter(view: view)
```

Run the work with one of the type of the presentation. The presenter will show corresponding loading/error screen depending on work result.

```swift
func doSomeStuff() -> Work<Int> {
    // do some work
}

loadingPresenter.helper.run(.opaque) {
    self.doSomeStuff()
}
```

## Meta

Ilya Kuznetsov – i.v.kuznecov@gmail.com

Distributed under the MIT license. See ``LICENSE`` for more information.

[https://github.com/ivkuznetsov](https://github.com/ivkuznetsov)
