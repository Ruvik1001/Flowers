from __future__ import annotations

from shared.auth import hash_password
from shared.errors import AppError
from shared.utils.ids import new_id

from app.domain.entities import Role, User
from app.domain.rbac import merge_permissions


class IdentityStore:
    def __init__(self) -> None:
        self.users: dict[str, User] = {}
        self.roles: dict[str, Role] = {}
        self.email_index: dict[str, str] = {}
        self._seed()

    def _seed(self) -> None:
        admin_role = Role(
            id=new_id(),
            name="admin",
            permissions=["*"],
        )
        self.roles[admin_role.id] = admin_role
        owner = Role(id=new_id(), name="owner", permissions=["*"])
        florist = Role(
            id=new_id(),
            name="florist",
            permissions=[
                "catalog.read",
                "catalog.write",
                "assembly.write",
                "inventory.read",
                "inventory.write_off",
            ],
        )
        cashier = Role(
            id=new_id(),
            name="cashier",
            permissions=["sales.write", "sales.read", "cashier.write", "cashier.read", "catalog.read"],
        )
        analyst = Role(
            id=new_id(),
            name="analyst",
            permissions=["analytics.read", "sales.read", "inventory.read", "cashier.read"],
        )
        for role in (owner, florist, cashier, analyst):
            self.roles[role.id] = role

    def bootstrap_admin(self, email: str, password: str) -> User:
        if email in self.email_index:
            return self.users[self.email_index[email]]
        admin_role = next(r for r in self.roles.values() if r.name == "admin")
        user = User(
            id=new_id(),
            email=email.lower(),
            password_hash=hash_password(password),
            is_admin=True,
            role_ids=[admin_role.id],
            object_scopes={"*": ["*"]},
        )
        self.users[user.id] = user
        self.email_index[user.email] = user.id
        return user

    def create_user(
        self,
        *,
        email: str,
        password: str,
        role_ids: list[str],
        is_admin: bool = False,
        object_scopes: dict[str, list[str]] | None = None,
    ) -> User:
        email_l = email.lower()
        if email_l in self.email_index:
            raise AppError("email_taken", "Email already registered", status_code=409)
        for role_id in role_ids:
            if role_id not in self.roles:
                raise AppError("role_not_found", f"Role {role_id} not found", status_code=404)
        user = User(
            id=new_id(),
            email=email_l,
            password_hash=hash_password(password),
            is_admin=is_admin,
            role_ids=role_ids,
            object_scopes=object_scopes or {},
        )
        self.users[user.id] = user
        self.email_index[email_l] = user.id
        return user

    def get_user(self, user_id: str) -> User:
        user = self.users.get(user_id)
        if not user:
            raise AppError("user_not_found", "User not found", status_code=404)
        return user

    def get_by_email(self, email: str) -> User:
        user_id = self.email_index.get(email.lower())
        if not user_id:
            raise AppError("invalid_credentials", "Invalid email or password", status_code=401)
        return self.users[user_id]

    def create_role(self, name: str, permissions: list[str]) -> Role:
        if any(r.name == name for r in self.roles.values()):
            raise AppError("role_exists", "Role already exists", status_code=409)
        role = Role(id=new_id(), name=name, permissions=permissions)
        self.roles[role.id] = role
        return role

    def permissions_for(self, user: User) -> list[str]:
        if user.is_admin:
            return ["*"]
        return merge_permissions([self.roles[rid].permissions for rid in user.role_ids if rid in self.roles])


store = IdentityStore()
