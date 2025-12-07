# Kubernetes & DevOps

## Table of Contents

- [Kubernetes Fundamentals](#kubernetes-fundamentals)
- [GitOps & ArgoCD](#gitops--argocd)
- [Networking & DNS](#networking--dns)
- [CI/CD Pipelines](#cicd-pipelines)

---

## Kubernetes Fundamentals

### Q: You have a fresh cluster and as an admin, you have your deployment manifest ready. What happens when you apply it?

**A:** When I apply a deployment manifest, here's the flow:

First, **kubectl** sends the manifest to the **API Server**, which authenticates me, validates the manifest, and stores the Deployment object in **etcd** as the desired state.

The **Deployment Controller** notices this new Deployment, compares it with the current state, and creates a **ReplicaSet** to manage the pods.

The **ReplicaSet Controller** then creates the specified number of Pod objects with a "Pending" status.

Next, the **Scheduler** watches for these pending pods, evaluates which nodes can run them based on resources and constraints, then assigns each pod to a suitable node.

The **kubelet** on each assigned node pulls the container images, instructs the container runtime to create the containers, sets up networking through CNI plugins, and mounts any volumes.

Finally, the pod transitions through states: Pending → ContainerCreating → Running, with the kubelet reporting status back to the API Server.

If there's a Service or Ingress in the manifest, **kube-proxy** configures network rules and the Ingress Controller sets up load balancing.

---

### Q: After the application starts, what three health checks happen?

**A:** Kubernetes performs three types of health checks:

**1. Startup Probe** - This runs first to determine if the application has started successfully. All other probes are disabled until this succeeds. It's useful for slow-starting applications that need more than 30 seconds to initialize. If it fails, the container is killed and restarted.

**2. Liveness Probe** - This checks if the application is still running and healthy. It runs continuously after the startup probe succeeds. If it fails after the configured attempts, the kubelet kills the container and restarts it according to the restart policy. It's great for detecting deadlocks or crashed applications.

**3. Readiness Probe** - This determines if the container is ready to accept traffic. It runs continuously throughout the pod's lifecycle. If it fails, the pod is removed from Service endpoints, but the container is NOT restarted. This handles temporary unavailability like warming up cache or waiting for dependencies.

The key difference: Startup asks "Has it started?", Liveness asks "Is it alive?", and Readiness asks "Can it handle traffic?"

---

### Q: What happens when the readiness probe fails?

**A:** When a readiness probe fails, several things happen:

The pod is immediately marked as "Not Ready" - you'll see this as `0/1` when you check pod status.

The pod is **removed from all Service endpoints**. Kube-proxy updates the iptables or IPVS rules to stop routing traffic to this pod, and the Endpoints or EndpointSlice objects are updated to exclude this pod's IP.

**No traffic is sent** to the pod through the Service anymore, though direct pod IP access still works if you bypass the Service.

Here's the important part: **the container keeps running** - it's not killed or restarted. Kubernetes will keep checking the readiness probe.

If the probe recovers and succeeds again, the pod is marked as Ready and added back to Service endpoints, and traffic resumes with no restart needed.

If it continues failing, the pod stays in "Not Ready" state indefinitely with no traffic routed to it, unless the liveness probe also fails.

For example, if a database connection pool is exhausted, the readiness probe fails, the pod stops receiving traffic, the pool recovers, readiness passes, and traffic resumes - all without a restart.

---

## GitOps & ArgoCD

### Q: When you apply a manifest through ArgoCD, what modifies the object?

**A:** Several components modify the object:

**ArgoCD Application Controller** watches the Git repository, detects differences between Git and the cluster, and initiates the sync operation. It adds tracking metadata like labels for the app instance and annotations for tracking ID and sync wave.

The **Kubernetes API Server** adds system fields like uid, resourceVersion, creationTimestamp, and generation.

Various **Kubernetes controllers** update the status section - the Deployment Controller updates replica status, the ReplicaSet Controller manages pod counts, and the kubelet updates pod conditions.

ArgoCD uses **Server-Side Apply** by default, which tracks field management. This means ArgoCD is recorded as the "field manager" in the managedFields section for the resources it deploys.

Additionally, **Admission Controllers or Webhooks** might mutate the spec by adding sidecars, injecting secrets, or making other modifications.

So essentially, ArgoCD applies the spec changes and adds tracking labels, while Kubernetes components add system metadata and update status fields.

---

### Q: There's a deployment deployed by GitOps with replicas set to 3 in Git. You apply an HPA with min 3 and max 5. What happens on the cluster?

**A:** This creates a conflict between GitOps and HPA fighting for control over the replicas field.

Here's what happens: When the HPA is applied, the **HPA Controller** detects it and starts monitoring metrics. It then **removes the replicas field** from the Deployment spec or sets it to null.

Now there's a drift: Git has `replicas: 3`, but the cluster has `replicas: <unset>` managed by HPA.

**ArgoCD detects this as "OutOfSync"** and keeps trying to reconcile by re-applying `replicas: 3`. This creates a continuous loop where ArgoCD applies the replica count, HPA removes it, ArgoCD detects drift, and the cycle continues.

**The solution** is to either:

**Option 1 (Recommended)**: Remove the replicas field entirely from your Git manifest. Let HPA have full control with no conflicts.

**Option 2**: Configure ArgoCD to ignore differences on the replicas field by adding it to ignoreDifferences in your Application manifest.

**Option 3**: Use Kustomize to remove the replicas field during rendering with a patch that removes the path `/spec/replicas`.

With the solution in place, HPA sets the initial replicas to 3 (minReplicas), monitors metrics, and scales up to 5 or down to 3 based on load, with no ArgoCD conflicts.

The best practice is to never specify replicas in your Deployment manifest when using HPA, and document that HPA controls the replica count.

---

## Networking & DNS

### Q: What happens when you paste a URL in the browser?

**A:** Let me walk you through the complete process:

**First, URL parsing**: The browser breaks down the URL into protocol (https), domain [www.example.com](www.example.com), port (443), path, query parameters, and fragment.

**Second, DNS lookup**: The browser needs to find the IP address. It checks the browser cache, then the OS cache, then the router cache. If not found, it queries DNS servers - starting with a recursive resolver (like your ISP or 8.8.8.8), which queries the root DNS server, then the TLD server (.com), then the authoritative DNS server, which finally returns the IP address.

**Third, TCP connection**: The browser initiates a 3-way handshake with the server - SYN, SYN-ACK, ACK - establishing a reliable connection.

**Fourth, TLS handshake** (for HTTPS): The browser and server exchange cipher suites, the server sends its certificate, the browser validates it, they exchange encryption keys, and establish an encrypted connection.

**Fifth, HTTP request**: The browser sends a formatted request with the method (GET, POST, etc.), path, headers (Host, User-Agent, Accept, cookies), and optionally a body for POST/PUT requests.

**Sixth, server processing**: A load balancer routes the request, the web server (Nginx/Apache) receives it, the application server processes the logic, database queries run if needed, and cache is checked.

**Seventh, HTTP response**: The server sends back a status code (200 OK, 404, etc.), headers (Content-Type, Cache-Control, cookies), and the response body (HTML, JSON, etc.).

**Eighth, browser rendering**: The browser parses HTML into the DOM, parses CSS into the CSSOM, builds a render tree, calculates layout, paints pixels, and composites layers.

**Ninth, JavaScript execution**: The JavaScript engine executes code, which may modify the DOM or fetch additional resources.

**Finally, loading additional resources**: The browser fetches CSS files, JavaScript files, images, fonts, and makes API calls - all in parallel where possible.

The whole process typically takes 500ms to 5 seconds depending on connection, server location, and page complexity.

---

### Q: How does the browser know to find the IP address?

**A:** The browser is programmed with built-in logic that recognizes when it has a domain name versus an IP address.

When you enter a URL, the browser parses the hostname. If it's a string with letters and domain extensions like .com or .org, it knows it needs to perform a DNS lookup. If it's already in IP format like 93.184.216.34, it can skip DNS and connect directly.

This is a fundamental requirement of how the Internet works - **networks route packets using IP addresses, not domain names**. Domain names are just a human-friendly layer on top.

Think of it like this: the domain name is "123 Main Street, Springfield" while the IP address is GPS coordinates. Networks need the "GPS coordinates" to route data packets.

The DNS lookup process has several steps: First, check the browser's DNS cache. Second, check the OS cache. Third, check the hosts file on your system. Fourth, query the DNS resolver (configured by your router via DHCP or manually set). Finally, if needed, the resolver performs a recursive query starting from root DNS servers (which are hardcoded into DNS resolver software), then TLD servers, then authoritative DNS servers.

Your computer knows where to send DNS queries because when you connect to WiFi, the router sends a DHCP offer that includes your IP address, gateway, and DNS server address (like 8.8.8.8). Your OS saves these settings and uses them when the browser needs to resolve a domain.

---

### Q: How do we make a request to a server? (Conceptually, not code)

**A:** Making a server request involves several steps:

**First, establish the destination**: You need the server's address (domain or IP) and port number (80 for HTTP, 443 for HTTPS).

**Second, resolve the domain**: If you have a domain name, perform DNS lookup to translate it to an IP address.

**Third, open a connection**: Initiate a TCP 3-way handshake with the server to create a reliable communication channel. It's like dialing the server's phone number.

**Fourth, secure the connection** (for HTTPS): Perform a TLS handshake to establish encryption, verify the server's certificate, and exchange encryption keys.

**Fifth, send the HTTP request**: This contains three parts:

- The request line: method (GET, POST, etc.), path (/users), and protocol version
- Headers: information like Host, User-Agent, Accept format, Authorization, Content-Type, and cookies
- Body (optional): the actual data you're sending, only for POST, PUT, or PATCH

**Sixth, server processes**: The server receives, parses, authenticates/authorizes, routes to the right handler, processes the logic (database queries, calculations), and prepares a response.

**Seventh, server responds**: The response includes a status line (status code like 200 OK or 404), response headers (Content-Type, Content-Length, Cache-Control), and the response body (the actual data).

**Eighth, receive and process**: Your client receives the response, reads the status code, parses headers, processes the body data, and displays or uses it.

**Finally, connection management**: Either close the connection or keep it alive for more requests.

Think of it like ordering food at a restaurant: find the restaurant (DNS), walk in and sit (TCP), tell the waiter what you want (HTTP request), kitchen prepares it (server processing), waiter brings your order (response), you eat (client processes), and either stay for dessert or leave (keep-alive or close).

---

## CI/CD Pipelines

### Q: For a Node.js application, what goes into its CI pipeline?

**A:** A typical Node.js CI pipeline has several stages:

**1. Code Checkout**: Pull the latest code from Git, checkout the specific branch or commit, and initialize any submodules.

**2. Environment Setup**: Install the specific Node.js version needed (like v18 or v20), set NODE_ENV to test or production, and load secrets from the CI secrets manager.

**3. Dependency Installation**: Run `npm ci` (not `npm install`) for a clean, reliable install using exact versions from package-lock.json. We cache node_modules for faster subsequent builds.

**4. Code Linting**: Run ESLint to check code quality and style, run Prettier to check formatting, and if using TypeScript, run type checking with `tsc --noEmit`.

**5. Unit Tests**: Run all unit tests with coverage reporting. We generate lcov or html coverage reports using Jest, Mocha, or Vitest.

**6. Integration Tests**: Start a test database in a Docker container, run integration tests against APIs and database connections, then clean up test data.

**7. Security Scanning**: Run `npm audit` to check for known vulnerabilities, use Snyk or Trivy for deeper security scans, and run OWASP dependency checks.

**8. Build Application**: If using TypeScript, compile it. Bundle and minify assets with Webpack or Vite, perform tree shaking, and generate source maps.

**9. Static Code Analysis**: Use SonarQube or Code Climate to analyze code quality metrics, check complexity, and detect code smells.

**10. Docker Image Build** (if containerized): Build the Docker image, tag it with version and commit hash, and scan the image for vulnerabilities.

**11. Push Artifacts**: Push the Docker image to a registry like ECR, GCR, or Docker Hub. Upload build artifacts and store test reports and coverage data.

**12. Optional stages**: End-to-end tests with Cypress or Playwright, performance tests with k6 or Artillery, and finally deployment to staging or production.

**Best practices** include using `npm ci` instead of `npm install` for reliability, caching dependencies, running jobs in parallel, using exact Node.js versions, testing on multiple Node versions with a matrix, and implementing quality gates like minimum 80% code coverage, no linting errors, all tests passing, and addressing security vulnerabilities.

Common tools include GitHub Actions, GitLab CI/CD, Jenkins, CircleCI, and Azure Pipelines. The pipeline automates everything from checkout to deployment, ensuring code quality, security, and reliability.
