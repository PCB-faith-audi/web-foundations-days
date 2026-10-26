# Day 8 Reflection

**Most difficult concept and how I overcame it**

The most difficult concept in this course was concurrency: understanding that two requests can read the same data at the same moment and both believe they are first. Transactions and race conditions made sense in theory, but I could not picture the failure until I traced two users buying the last seat step by step on paper. Writing the timeline (check the seat, then update the seat) showed me the gap between the two steps. Once I saw that gap, atomic updates, row locks and unique constraints stopped feeling like jargon and became tools that close it. I confirmed my understanding by designing TicketHub so the database itself refuses a double sale.

**What I would improve in my capstone**

Based on the feedback I received, I would improve my capstone, Ujima AI, in three areas: security, reliability and clarity. I would add stricter input validation, authentication checks and rate limiting to the Express backend, since a lending support tool handles sensitive member data. I would add automated tests for the three agents so changes do not silently break them, and handle Groq model failures gracefully with clear fallback messages. I would also document the setup and deployment steps so a reviewer can run the project without my help.

**What I will learn next**

Next, I want to finish the AWS AI Practitioner path and learn to deploy applications on cloud services, including queues, caching and monitoring, the same building blocks I used in this design. I also want to learn how to load-test systems, so I can prove a design survives pressure rather than only claim that it does.