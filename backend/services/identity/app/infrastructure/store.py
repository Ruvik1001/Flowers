from __future__ import annotations

from sqlalchemy import delete, select

from shared.auth import hash_password
from shared.errors import AppError
from shared.persistence.models import RoleRow, UserRow
from shared.persistence.persist_map import PersistMap
from shared.persistence.runtime import db_session, persistence_enabled
from shared.utils.ids import new_id

from app.domain.entities import Role, User
from app.domain.rbac import merge_permissions


def _role_from_row(row: RoleRow) -> Role:
    return Role(id=row.id, name=row.name, permissions=list(row.permissions or []))


def _user_from_row(row: UserRow) -> User:
    return User(
        id=row.id,
        email=row.email,
        password_hash=row.password_hash,
        is_admin=bool(row.is_admin),
        is_active=bool(row.is_active),
        role_ids=list(row.role_ids or []),
        object_scopes=dict(row.object_scopes or {}),
    )


class IdentityStore:
    def __init__(self) -> None:
        self._persist = persistence_enabled()
        self.users: PersistMap[str, User] = PersistMap(
            on_set=self._save_user if self._persist else None,
            on_del=self._delete_user if self._persist else None,
            on_clear=self._clear_users if self._persist else None,
        )
        self.roles: PersistMap[str, Role] = PersistMap(
            on_set=self._save_role if self._persist else None,
            on_del=self._delete_role if self._persist else None,
            on_clear=self._clear_roles if self._persist else None,
        )
        self.email_index: dict[str, str] = {}
        if self._persist:
            self._load()
        if not self.roles:
            self._seed()

    def _load(self) -> None:
        with db_session() as session:
            roles = [_role_from_row(r) for r in session.scalars(select(RoleRow)).all()]
            users = [_user_from_row(u) for u in session.scalars(select(UserRow)).all()]
        self.roles.replace_all((r.id, r) for r in roles)
        self.users.replace_all((u.id, u) for u in users)
        self.email_index = {u.email: u.id for u in users}

    def _save_role(self, role_id: str, role: Role) -> None:
        with db_session() as session:
            row = session.get(RoleRow, role_id) or RoleRow(id=role_id)
            row.name = role.name
            row.permissions = list(role.permissions)
            session.merge(row)

    def _delete_role(self, role_id: str) -> None:
        with db_session() as session:
            row = session.get(RoleRow, role_id)
            if row:
                session.delete(row)

    def _clear_roles(self) -> None:
        with db_session() as session:
            session.execute(delete(RoleRow))

    def _clear_users(self) -> None:
        with db_session() as session:
            session.execute(delete(UserRow))

    def _save_user(self, user_id: str, user: User) -> None:
        with db_session() as session:
            row = session.get(UserRow, user_id) or UserRow(id=user_id)
            row.email = user.email
            row.password_hash = user.password_hash
            row.is_admin = user.is_admin
            row.is_active = user.is_active
            row.role_ids = list(user.role_ids)
            row.object_scopes = dict(user.object_scopes)
            session.merge(row)

    def _delete_user(self, user_id: str) -> None:
        with db_session() as session:
            row = session.get(UserRow, user_id)
            if row:
                session.delete(row)

    def _seed(self) -> None:
        admin_role = Role(id=new_id(), name="admin", permissions=["*"])
        self.roles[admin_role.id] = admin_role
        for role in (
            Role(id=new_id(), name="owner", permissions=["*"]),
            Role(
                id=new_id(),
                name="florist",
                permissions=[
                    "catalog.read",
                    "catalog.write",
                    "assembly.write",
                    "inventory.read",
                    "inventory.write",
                    "inventory.write_off",
                    "procurement.read",
                    "procurement.write",
                    "files.read",
                    "files.write",
                ],
            ),
            Role(
                id=new_id(),
                name="cashier",
                permissions=["sales.write", "sales.read", "cashier.write", "cashier.read", "catalog.read"],
            ),
            Role(
                id=new_id(),
                name="analyst",
                permissions=["analytics.read", "sales.read", "inventory.read", "cashier.read"],
            ),
        ):
            self.roles[role.id] = role

    def bootstrap_admin(self, email: str, password: str) -> User:
        if email.lower() in self.email_index:
            return self.users[self.email_index[email.lower()]]
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
