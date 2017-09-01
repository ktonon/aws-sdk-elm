AWS SDK for elm
===============

__Deprecated__

The idea of having a single fully generated Elm package for every AWS service was abandoned for the following reasons:

* Breaking changes to one service would require a Major version bump for the entire service
* It was difficult to come up with nice, user-friendly, fully generated, APIs for every service

This repo has been split into 2 separate repos, each with a specific purpose:

* [elm-aws-core][] For making authenticated REST requests to AWS services using pure Elm.
* [elm-aws-generate][] Elm code generation from AWS JSON service files. The generated code is intended to be a starting point, from which a developer can create a nice, user-friendly client, tailored to a specific AWS service.

[elm-aws-core]:https://github.com/ktonon/elm-aws-core
[elm-aws-generate]:https://github.com/ktonon/elm-aws-generate
