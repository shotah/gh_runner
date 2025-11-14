# Architecture Diagram

## Current Implementation (AWS CDK)

```mermaid
graph TB
    subgraph GitHub
        A[GitHub Workflow Job]
        B[Workflow Triggered]
    end

    subgraph AWS Cloud
        subgraph API Layer
            C[API Gateway<br/>POST /]
        end

        subgraph Lambda Functions
            D[Webhook Lambda<br/>Python 3.13<br/>256MB, 30s]
            E[Runner Lambda<br/>Docker Container<br/>3008MB, 15min]
        end

        subgraph Storage
            F[Secrets Manager<br/>- GitHub Token<br/>- Webhook Secret]
            G[ECR<br/>Runner Docker Image<br/>Pre-baked Runner]
        end

        subgraph Logs
            H[CloudWatch Logs<br/>7-day retention]
        end
    end

    subgraph Docker Image
        I[Base: lambda/python:3.13]
        J[AWS CLI v2]
        K[SAM CLI]
        L[GitHub Runner<br/>Latest version]
        M[Python 3.13 + Git]
    end

    B -->|1. Job queued webhook| C
    C -->|2. Invoke| D
    D -->|3. Validate signature| F
    D -->|4. Async invoke| E
    E -->|5. Get GitHub token| F
    E -->|6. Pull image| G
    E -->|7. Register runner| A
    E -->|8. Execute job| A
    E -->|9. Log output| H
    
    G -.->|Contains| I
    I -.->|Includes| J
    I -.->|Includes| K
    I -.->|Includes| L
    I -.->|Includes| M

    style D fill:#ff9900
    style E fill:#ff9900
    style G fill:#00a8e1
    style F fill:#dd344c
    style H fill:#146eb4
```

## Component Flow

```mermaid
sequenceDiagram
    participant GH as GitHub
    participant APIG as API Gateway
    participant WHL as Webhook Lambda
    participant SM as Secrets Manager
    participant RL as Runner Lambda
    participant ECR as ECR
    participant CW as CloudWatch

    GH->>APIG: POST /webhook (workflow_job queued)
    APIG->>WHL: Invoke webhook handler
    WHL->>SM: Get webhook secret
    SM-->>WHL: Return secret
    WHL->>WHL: Verify HMAC signature
    WHL->>WHL: Check labels (self-hosted)
    WHL->>RL: Async invoke runner
    WHL-->>APIG: 200 OK
    APIG-->>GH: 200 OK

    RL->>SM: Get GitHub token
    SM-->>RL: Return token
    RL->>ECR: Pull runner image
    ECR-->>RL: Return image
    RL->>RL: Copy runner to /tmp
    RL->>GH: Get registration token
    GH-->>RL: Return reg token
    RL->>RL: Configure ephemeral runner
    RL->>GH: Register and claim job
    RL->>RL: Execute workflow steps
    RL->>CW: Stream logs
    RL->>GH: Report job status
    RL->>RL: Cleanup and exit
```

## Deployment Architecture (CDK)

```mermaid
graph LR
    subgraph Developer Machine
        A[TypeScript Code]
        B[CDK App]
        C[.env file]
    end

    subgraph CDK Deployment
        D[cdk deploy]
        E[CloudFormation]
    end

    subgraph AWS Resources
        F[Lambda Functions]
        G[API Gateway]
        H[Secrets Manager]
        I[ECR Repository]
        J[IAM Roles]
        K[Log Groups]
    end

    A -->|npm run build| B
    C -->|Environment vars| B
    B -->|cdk deploy| D
    D -->|Generate| E
    E -->|Creates| F
    E -->|Creates| G
    E -->|Creates| H
    E -->|Creates| I
    E -->|Creates| J
    E -->|Creates| K
```

---

## What Would SAM Look Like?

If we convert to SAM, the structure would be:

```mermaid
graph TB
    subgraph Developer Machine
        A[template.yaml<br/>SAM Template]
        B[samconfig.toml<br/>Configuration]
        C[.env file]
    end

    subgraph SAM Deployment
        D[sam build]
        E[sam deploy]
        F[CloudFormation]
    end

    subgraph AWS Resources
        G[Lambda Functions]
        H[API Gateway]
        I[Secrets Manager]
        J[ECR Repository]
        K[IAM Roles]
        L[Log Groups]
    end

    A -->|sam build| D
    D -->|Creates .aws-sam/| E
    C -->|Environment vars| E
    E -->|Generate| F
    F -->|Creates| G
    F -->|Creates| H
    F -->|Creates| I
    F -->|Creates| J
    F -->|Creates| K
    F -->|Creates| L
```

---

## Key Differences: CDK vs SAM

| Aspect | Current (CDK) | Proposed (SAM) |
|--------|---------------|----------------|
| **Language** | TypeScript | YAML |
| **Structure** | OOP, programmatic | Declarative |
| **Files** | `lib/*.ts`, `bin/*.ts` | `template.yaml` |
| **Build** | `npm run build`, `cdk synth` | `sam build` |
| **Deploy** | `cdk deploy` | `sam deploy` |
| **Local Testing** | Not supported | `sam local invoke` |
| **Complexity** | Higher (more flexible) | Lower (simpler) |
| **Learning Curve** | Steeper | Gentler |

---

## Questions Before Converting

1. **Do you have an existing SAM template pattern?** (from aws_fastapi_template?)
2. **What's the reason for SAM over CDK?** (team preference, existing patterns, local testing?)
3. **Timeline?** (Is this urgent or can we evaluate first?)
4. **Keep what we have?** (Some features, scripts, documentation?)

Would you like me to:
- ✅ See your `aws_fastapi_template` to match the pattern?
- ✅ Create a SAM template matching current functionality?
- ✅ Keep CDK but add SAM as deployment option?
- ✅ Just create diagrams for approval of current design?

