Understood. We'll design the complete three-tier application infrastructure, from source code and CI/CD through production-style deployment on AWS—not just the CI pipeline.

We'll use your existing `DevOps-Project-01` repository and finalize the Terraform configuration before creating any AWS resources.

# Target architecture: complete three-tier application on AWS

<img width="796" height="744" alt="image" src="https://github.com/user-attachments/assets/592035e8-0253-43b1-97c6-600a751242c6" />


The three tiers will be separated logically and through network policies/security controls. The load balancer is the public entry point; the application and database tiers won't be directly exposed to the internet.
# Final architecture decisions

<img width="817" height="441" alt="image" src="https://github.com/user-attachments/assets/df982e8e-46a9-4425-9173-f3026afda3b4" />


## 1. Full project scope

<img width="802" height="628" alt="image" src="https://github.com/user-attachments/assets/987f8649-10d1-4d4f-a25b-6e8a448ea476" />


## 2. End-to-end delivery flow

<img width="998" height="3166" alt="mermaid-diagram" src="https://github.com/user-attachments/assets/9f57fec4-5d6b-4c91-b6d8-861489a13111" />


The pipeline should promote the same image digest through deployment stages rather than rebuilding the image for each environment. Argo CD manages deployment state from Git; rollback must account for both application health and GitOps reconciliation.

