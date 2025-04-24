## 1. Why Dapr?

Dapr, the Distributed Application Runtime, is used by many large enterprises, such as Grafana, Zeiss, and FICO, to speed up distributed application development. On average, application developers save 30% of development time when using Dapr, compared to not using Dapr for building back-end applications.

Dapr provides APIs, which decouples your application code from the underlying infrastructure your applications are using, such as data stores, message brokers, secret stores and many others. This means that your code does not use any resource-specific code or dependencies, and you can easily swap out these resources without any code changes.

## 2. Developing with Dapr

You can use any language when building distributed applications with Dapr, since Dapr runs in a separate process next to your application. This type of architecture is called the *sidecar pattern*. The benefit of using this pattern is that cross-cutting concerns such as observability, security, and resiliency are not part of your application code but abstracted away in the Dapr sidecar. This results in cleaner application code that is easier to maintain.

![Dapr overview](https://docs.dapr.io/images/overview.png)

Your application communicates with the Dapr sidecar via HTTP or gRPC. Dapr also offers client SDKs that make it even easier to communicate with the sidecar, especially for typed languages.

Currentely Dapr has SDKs for these languages:
- .NET
- Java
- Python
- JavaScript
- Go
- Rust
- PHP

## 3. Dapr features

Dapr offers many building block APIs that speed up back-end application development:

- **Service invocation**: Perform synchronous, secure, service-to-service method calls
- **State Management**: Manage key/value data in your services
- **Pub/Sub**: Secure, scalable asynchronous messaging between services
- **Workflow**: Automate and orchestrate tasks within your application
- **Actors**: Encapsulate code and data in reusable actor objects as a common microservices design pattern
- **Bindings**: Input and output bindings to external resources, including databases and queues
- **Configuration**: Access application configuration and be notified of updates
- **Distributed lock**: Mutually exclusive access to shared resources
- **Secrets**: Securely access secrets from your application
- **Cryptography**: Perform operations for encrypting and decrypting data
- **Jobs**: Scheduled tasks to run at specified intervals or times
- **Conversation**:  Converse with different large language models (LLMs)

Dapr also provides built-in capabilities for **security**, **observability**, and **resiliency**.

---

This Dapr 101 learning track covers the State Management, Service Invocation, and Pub/Sub APIs. Future learning tracks will cover more APIs and cross-cutting concerns.
